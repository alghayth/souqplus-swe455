import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlng;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:souqplus/components/app_bottom_nav.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/services/category_service.dart';
import 'package:souqplus/services/seller_stripe_service.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

class _UploadedImageResult {
  const _UploadedImageResult({
    required this.bucket,
    required this.path,
    required this.downloadUrl,
  });

  final String bucket;
  final String path;
  final String downloadUrl;
}

class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key});
  static String routeName = "/seller";

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  static const latlng.LatLng _defaultCenter = latlng.LatLng(24.7136, 46.6753);
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  List<String> _categories = [...CategoryService.defaultCategories];
  StreamSubscription<List<String>>? _categorySubscription;

  String _selectedCategory = 'Books';
  File? _selectedImage;
  String? _selectedImageSource;
  latlng.LatLng? _selectedLatLng;
  String? _selectedLocationDetails;

  bool _isSubmitting = false;
  bool _isLocatingUser = false;
  bool _isResolvingAddress = false;
  bool _showImageError = false;
  bool _showLocationError = false;
  final MapController _mapController = MapController();

  String? _validateProductTitle(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Product title is required';
    }
    if (text.length < 3) {
      return 'Product title must be at least 3 characters';
    }
    return null;
  }

  String? _validateProductPrice(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Price in Saudi riyal is required';
    }
    final price = double.tryParse(text);
    if (price == null || price <= 0) {
      return 'Enter a valid price in Saudi riyal';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _categorySubscription = CategoryService.categoriesStream().listen((categories) {
      if (!mounted) return;
      setState(() {
        _categories = categories.isEmpty
            ? [...CategoryService.defaultCategories]
            : categories;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = _categories.first;
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverLostImageIfAny();
      _autoDetectUserLocation(showErrorMessage: false);
    });
  }

  @override
  void dispose() {
    _categorySubscription?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (image == null || !mounted) return;

      _applyPickedImage(
        image,
        source == ImageSource.camera ? 'camera' : 'gallery',
      );
    } catch (e) {
      _showSnack('Could not open ${source.name}. Please try again.');
    }
  }

  Future<void> _recoverLostImageIfAny() async {
    try {
      final lostData = await _picker.retrieveLostData();
      if (!mounted || lostData.isEmpty || lostData.file == null) return;
      _applyPickedImage(lostData.file!, 'camera');
    } catch (_) {
      // ignore
    }
  }

  void _applyPickedImage(XFile image, String sourceLabel) {
    setState(() {
      _selectedImage = File(image.path);
      _selectedImageSource = sourceLabel;
      _showImageError = false;
    });
  }

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take Photo with Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;
    await _pickImageFromSource(source);
  }

  Future<_UploadedImageResult?> _uploadImage(File imageFile, String uid) async {
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';

    final Reference storageRef = FirebaseStorage.instance
        .ref()
        .child('product_images')
        .child(uid)
        .child(fileName);

    try {
      final TaskSnapshot snapshot = await storageRef.putFile(imageFile);
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return _UploadedImageResult(
        bucket: snapshot.ref.bucket,
        path: snapshot.ref.fullPath,
        downloadUrl: downloadUrl,
      );
    } on FirebaseException catch (e) {
      debugPrint('STORAGE ERROR: ${e.code} - ${e.message}');
      _showSnack('Failed to upload image: ${e.message ?? e.code}');
      return null;
    } catch (e) {
      debugPrint('STORAGE ERROR (general): $e');
      _showSnack('An unexpected error occurred during image upload.');
      return null;
    }
  }

  Future<void> _submitProduct() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      _showSnack('Please fill in all required fields.');
      return;
    }
    if (_selectedImage == null) {
      setState(() => _showImageError = true);
      _showSnack('Please select a product image.');
      return;
    }
    if (_selectedLatLng == null) {
      setState(() => _showLocationError = true);
      _showSnack('Please choose pickup location on map.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('You must be logged in to post a product.');
      return;
    }

    final userDoc = await db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final sellerStripeAccountId = (userData['stripeAccountId'] as String? ?? '')
        .trim();
    if (sellerStripeAccountId.isEmpty) {
      _showSnack('Connect Stripe before posting a product.');
      return;
    }

    final hasStripeAccount = await _ensureSellerStripeAccount(user);
    if (!hasStripeAccount) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      debugPrint('DEBUG: posting as uid=${user.uid} email=${user.email}');

      // 1) Upload image
      final uploadedImage = await _uploadImage(_selectedImage!, user.uid);
      if (uploadedImage == null) {
        debugPrint('DEBUG: uploadImage returned null -> stop');
        return;
      }
      debugPrint('DEBUG: upload ok url=${uploadedImage.downloadUrl}');

      // 2) Save to Firestore
      final data = <String, dynamic>{
        'ownerUid': user.uid, // MUST match rules exactly
        'ownerEmail': user.email,
        'sellerStripeAccountId': sellerStripeAccountId,
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'status': 'Active',
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'pickupAddress': GeoPoint(
          _selectedLatLng!.latitude,
          _selectedLatLng!.longitude,
        ),
        'pickupLocationDetails': _selectedLocationDetails ?? '',
        'imageUrl': uploadedImage.downloadUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': Timestamp.now(),
      };

      debugPrint('DEBUG: firestore write data=$data');

      final docRef = await db.collection('products').add(data);
      debugPrint('DEBUG: Firestore created docId=${docRef.id}');

      if (!mounted) return;
      _showSnack('Product posted successfully!');

      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _formKey.currentState!.reset();

      setState(() {
        _selectedCategory = 'Books';
        _selectedImage = null;
        _selectedImageSource = null;
        _selectedLatLng = null;
        _selectedLocationDetails = null;
        _showImageError = false;
        _showLocationError = false;
      });

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      // THIS is the important part: it will show permission-denied if rules block.
      debugPrint('FIRESTORE ERROR: ${e.code} - ${e.message}');
      _showSnack('Failed to post product: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('UNEXPECTED ERROR: $e');
      _showSnack('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureSellerStripeAccount(User user) async {
    final result = await SellerStripeService.ensureConnectedBeforePosting(
      context,
      user: user,
      successReminder:
          'Complete Stripe onboarding, then tap post product again.',
    );
    return result == SellerStripePostingAccess.connected;
  }

  Future<void> _autoDetectUserLocation({bool showErrorMessage = false}) async {
    setState(() => _isLocatingUser = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showErrorMessage) _showSnack('Please enable location services.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showErrorMessage) {
          _showSnack(
            permission == LocationPermission.deniedForever
                ? 'Location permission is permanently denied. Enable it from app settings.'
                : 'Location permission is required.',
          );
        }
        return;
      }

      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } on TimeoutException {
        currentPosition = await Geolocator.getLastKnownPosition();
      }

      if (currentPosition == null) {
        if (showErrorMessage) {
          _showSnack(
            'Could not get current location. Try moving outdoors and retry.',
          );
        }
        return;
      }

      final userLatLng = latlng.LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      await _setPickedLocation(userLatLng, moveCamera: true);
      if (showErrorMessage) {
        _showSnack('Current location selected successfully.');
      }
    } catch (e) {
      if (showErrorMessage) {
        final message = e.toString();
        if (message.contains('Location services are disabled')) {
          _showSnack('Location service is disabled on your phone.');
        } else if (message.contains('permission')) {
          _showSnack('Location permission denied.');
        } else {
          _showSnack('Failed to detect current location: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isLocatingUser = false);
    }
  }

  Future<void> _setPickedLocation(
    latlng.LatLng pickedLocation, {
    bool moveCamera = false,
  }) async {
    setState(() {
      _selectedLatLng = pickedLocation;
      _isResolvingAddress = true;
      _showLocationError = false;
    });

    if (moveCamera) {
      _mapController.move(pickedLocation, 16);
    }

    await _resolveLocationDetails(pickedLocation);
  }

  Future<void> _resolveLocationDetails(latlng.LatLng pickedLocation) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        pickedLocation.latitude,
        pickedLocation.longitude,
      );
      if (!mounted) return;

      if (placemarks.isEmpty) {
        setState(() {
          _selectedLocationDetails = 'Unknown location';
          _isResolvingAddress = false;
        });
        return;
      }

      final p = placemarks.first;
      final parts = <String>[
        if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.administrativeArea ?? '').trim().isNotEmpty)
          p.administrativeArea!.trim(),
        if ((p.country ?? '').trim().isNotEmpty) p.country!.trim(),
      ];

      setState(() {
        _selectedLocationDetails = parts.isEmpty
            ? 'Unknown location'
            : parts.join(', ');
        _isResolvingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedLocationDetails = 'Unable to resolve address';
        _isResolvingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'Create Product',
          style: TextStyle(
            color: Color.fromARGB(255, 236, 180, 77),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildImagePicker(),
              if (_showImageError) ...[
                const SizedBox(height: 8),
                const Text(
                  'Product image is required.',
                  style: TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Product Title'),
                validator: _validateProductTitle,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLength: 100,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.length < 10 || text.length > 100) {
                    return 'Description must be between 10 and 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Price in Saudi Riyal',
                  prefixText: 'Riyal ',
                  helperText: 'Enter the amount in Saudi riyal',
                ),
                validator: _validateProductPrice,
              ),
              const SizedBox(height: 16),
              _buildAddressPickerCard(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitProduct,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_outlined),
                label: Text(_isSubmitting ? 'Posting...' : 'Post Product'),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
      floatingActionButton: const AppNavFab(isSellerPage: true),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const AppBottomNav(selectedIndex: -1),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _showImageSourceSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kTextColor),
          color: Colors.white.withAlpha(80),
        ),
        child: _selectedImage == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 38,
                      color: kTextColor,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Choose Gallery or Camera',
                      style: TextStyle(color: kTextColor),
                    ),
                  ],
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_selectedImage!, fit: BoxFit.cover),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            _selectedImageSource == 'camera'
                                ? 'Camera'
                                : 'Gallery',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAddressPickerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kTextColor),
        color: Colors.white.withAlpha(80),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pickup Location',
            style: TextStyle(
              color: kTextColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 13,
                  onTap: (tapPosition, point) => _setPickedLocation(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.souqplus',
                  ),
                  if (_selectedLatLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLatLng!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLatLng == null
                ? 'Tap on map to place pickup pin'
                : 'Pin set',
            style: const TextStyle(color: kTextColor),
          ),
          if (_showLocationError) ...[
            const SizedBox(height: 6),
            const Text(
              'Pickup location is required.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          if (_selectedLatLng != null) ...[
            const SizedBox(height: 6),
            Text(
              _isResolvingAddress
                  ? 'Resolving location details...'
                  : (_selectedLocationDetails ?? 'Unknown location'),
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isLocatingUser
                ? null
                : () => _autoDetectUserLocation(showErrorMessage: true),
            icon: _isLocatingUser
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text(
              _isLocatingUser ? 'Detecting...' : 'Use Current Location',
            ),
          ),
          if (_selectedLatLng != null) ...[
            const SizedBox(height: 6),
            Text(
              'Lat: ${_selectedLatLng!.latitude.toStringAsFixed(6)}, '
              'Lng: ${_selectedLatLng!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: kTextColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
