import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/constants.dart';
import 'package:souqplus/services/admin_order_service.dart';

class AdminRecordsScreen extends StatelessWidget {
  static const String routeName = '/admin_records';

  const AdminRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const service = AdminOrderService();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 253, 246, 210),
        appBar: AppBar(
          backgroundColor: kSecondaryColor,
          title: const PageHeaderTitle('Database'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xCCEAF5FC),
            indicatorColor: kPrimaryColor,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Products'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersRecordsTab(service: service),
            _ProductsRecordsTab(service: service),
          ],
        ),
      ),
    );
  }
}

class _UsersRecordsTab extends StatefulWidget {
  const _UsersRecordsTab({required this.service});

  final AdminOrderService service;

  @override
  State<_UsersRecordsTab> createState() => _UsersRecordsTabState();
}

class _UsersRecordsTabState extends State<_UsersRecordsTab> {
  String? _updatingUserId;

  Future<void> _confirmSetBlocked({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool blocked,
  }) async {
    final data = doc.data();
    final email = _text(data, 'email', fallback: 'this user');
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked ? 'Block User' : 'Unblock User'),
        content: Text(
          blocked
              ? 'Are you sure you want to block $email? This user will not be able to sign in.'
              : 'Are you sure you want to unblock $email? This user will be able to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              blocked ? 'Block' : 'Unblock',
              style: TextStyle(color: blocked ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );

    if (shouldUpdate != true) return;
    await _setBlocked(doc: doc, blocked: blocked);
  }

  Future<void> _setBlocked({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool blocked,
  }) async {
    setState(() => _updatingUserId = doc.id);
    try {
      await widget.service.updateUserBlocked(userId: doc.id, blocked: blocked);
      if (!mounted) return;
      final email = _text(doc.data(), 'email', fallback: 'This user');
      await _showAccessUpdatedMessage(email: email, blocked: blocked);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update user access: $error')),
      );
    } finally {
      if (mounted) setState(() => _updatingUserId = null);
    }
  }

  Future<void> _showAccessUpdatedMessage({
    required String email,
    required bool blocked,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked ? 'User Blocked' : 'User Unblocked'),
        content: Text(
          blocked
              ? '$email has been blocked successfully.'
              : '$email has been unblocked successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAdminUid = FirebaseAuth.instance.currentUser?.uid;

    return _RecordsList(
      stream: widget.service.usersStream(),
      emptyText: 'No registered users found in the database.',
      filterDocs: (docs) {
        docs.removeWhere(
          (doc) => _text(doc.data(), 'email', fallback: '').isEmpty,
        );
      },
      sortDocs: (docs) {
        docs.sort((a, b) {
          final aEmail = _text(a.data(), 'email', fallback: '').toLowerCase();
          final bEmail = _text(b.data(), 'email', fallback: '').toLowerCase();
          return aEmail.compareTo(bEmail);
        });
      },
      itemBuilder: (doc) {
        final data = doc.data();
        final isBlocked = _isBlocked(data);
        final isAdmin = _isAdminRecord(data);
        final isCurrentAdmin = doc.id == currentAdminUid;
        final canBlock = !isAdmin && !isCurrentAdmin;
        final isUpdating = _updatingUserId == doc.id;
        final email = _text(data, 'email', fallback: 'No email');
        final fullName = _displayName(data);

        return _RecordCard(
          title: fullName,
          subtitle: '',
          badgeText: isBlocked ? 'Blocked' : 'Active',
          badgeColor: isBlocked ? Colors.red : Colors.green,
          lines: [
            'Email: $email',
            'Phone: ${_text(data, 'phoneNumber', fallback: 'Not set')}',
            'UID: ${_text(data, 'uid', fallback: doc.id)}',
          ],
          action: canBlock
              ? ElevatedButton.icon(
                  onPressed: isUpdating
                      ? null
                      : () => _confirmSetBlocked(
                          doc: doc,
                          blocked: !isBlocked,
                        ),
                  icon: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isBlocked
                              ? Icons.lock_open_rounded
                              : Icons.block_rounded,
                        ),
                  label: Text(isBlocked ? 'Unblock User' : 'Block User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE8EEF5),
                    disabledForegroundColor: const Color(0xFF6B7C93),
                  ),
                )
              : const Text(
                  'Admin accounts cannot be blocked here.',
                  style: TextStyle(
                    color: Color(0xFF6B7C93),
                    fontWeight: FontWeight.w600,
                  ),
                ),
        );
      },
    );
  }
}

class _ProductsRecordsTab extends StatefulWidget {
  const _ProductsRecordsTab({required this.service});

  final AdminOrderService service;

  @override
  State<_ProductsRecordsTab> createState() => _ProductsRecordsTabState();
}

class _ProductsRecordsTabState extends State<_ProductsRecordsTab> {
  String? _removingProductId;

  Future<void> _confirmRemoveProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final title = _text(data, 'title', fallback: 'this product post');
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Product Post'),
        content: Text(
          'Remove "$title" from SouqPlus? This will delete the product post from Firebase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;
    await _removeProduct(doc: doc, title: title);
  }

  Future<void> _removeProduct({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String title,
  }) async {
    setState(() => _removingProductId = doc.id);
    try {
      await widget.service.removeProductPost(productId: doc.id);
      if (!mounted) return;
      await _showProductRemovedMessage(title);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove product post: $error')),
      );
    } finally {
      if (mounted) setState(() => _removingProductId = null);
    }
  }

  Future<void> _showProductRemovedMessage(String title) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Post Removed'),
        content: Text('"$title" was removed successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _RecordsList(
      stream: widget.service.productsStream(),
      emptyText: 'No active product posts found in Firebase.',
      filterDocs: (docs) {
        docs.removeWhere((doc) => !_isActiveProduct(doc.data()));
      },
      sortDocs: (docs) {
        docs.sort((a, b) {
          final aTitle = _text(a.data(), 'title', fallback: '').toLowerCase();
          final bTitle = _text(b.data(), 'title', fallback: '').toLowerCase();
          return aTitle.compareTo(bTitle);
        });
      },
      itemBuilder: (doc) {
        final data = doc.data();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        final isRemoving = _removingProductId == doc.id;
        return _RecordCard(
          title: _text(data, 'title', fallback: 'Untitled product'),
          subtitle: 'SAR ${price.toStringAsFixed(2)}',
          badgeText: _text(data, 'status', fallback: 'Unknown'),
          badgeColor: _productStatusColor(data),
          imageUrl: _productImageUrl(data),
          description: _text(
            data,
            'description',
            fallback: 'No description provided.',
          ),
          lines: [
            'Category: ${_text(data, 'category', fallback: 'Not set')}',
            'Seller: ${_text(data, 'ownerEmail', fallback: 'No seller email')}',
            'Owner UID: ${_text(data, 'ownerUid', fallback: 'Not set')}',
            'Product ID: ${doc.id}',
          ],
          action: ElevatedButton.icon(
            onPressed: isRemoving ? null : () => _confirmRemoveProduct(doc),
            icon: isRemoving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE8EEF5),
              disabledForegroundColor: const Color(0xFF6B7C93),
            ),
          ),
        );
      },
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.stream,
    required this.emptyText,
    required this.itemBuilder,
    this.filterDocs,
    this.sortDocs,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyText;
  final void Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)?
  filterDocs;
  final void Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)?
  sortDocs;
  final Widget Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
  itemBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FirebaseMessage(
            icon: Icons.cloud_off_rounded,
            text: 'Firebase could not load this data: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...?snapshot.data?.docs];
        filterDocs?.call(docs);
        sortDocs?.call(docs);
        if (docs.isEmpty) {
          return _FirebaseMessage(icon: Icons.inbox_rounded, text: emptyText);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) => itemBuilder(docs[index]),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.title,
    required this.subtitle,
    required this.lines,
    this.badgeText,
    this.badgeColor,
    this.imageUrl,
    this.description,
    this.action,
  });

  final String title;
  final String subtitle;
  final List<String> lines;
  final String? badgeText;
  final Color? badgeColor;
  final String? imageUrl;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _adminCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? kSecondaryColor).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      color: badgeColor ?? kSecondaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kSecondaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (imageUrl != null) ...[
            const SizedBox(height: 12),
            _ProductImagePreview(imageUrl: imageUrl!),
          ],
          if (description != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Description',
              style: TextStyle(
                color: kTextColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description!,
              style: const TextStyle(
                color: Color(0xFF4C5F73),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6B7C93), fontSize: 11),
              ),
            ),
          if (action != null) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: action!),
          ],
        ],
      ),
    );
  }
}

class _ProductImagePreview extends StatelessWidget {
  const _ProductImagePreview({required this.imageUrl});

  final String imageUrl;

  bool get _isNetworkImage =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
          child: _isNetworkImage
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _MissingProductImage(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                )
              : Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _MissingProductImage(),
                ),
        ),
      ),
    );
  }
}

class _MissingProductImage extends StatelessWidget {
  const _MissingProductImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFF8A9AAF),
        size: 34,
      ),
    );
  }
}

class _FirebaseMessage extends StatelessWidget {
  const _FirebaseMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kSecondaryColor, size: 38),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _text(
  Map<String, dynamic> data,
  String field, {
  required String fallback,
}) {
  final value = (data[field] as String? ?? '').trim();
  return value.isEmpty ? fallback : value;
}

String _displayName(Map<String, dynamic> data) {
  final fullName = _text(data, 'fullName', fallback: '');
  if (fullName.isNotEmpty) return fullName;

  final firstName = _text(data, 'firstName', fallback: '');
  final lastName = _text(data, 'lastName', fallback: '');
  final name = '$firstName $lastName'.trim();
  return name.isEmpty ? 'Registered User' : name;
}

bool _isBlocked(Map<String, dynamic> data) {
  final status = (data['status'] as String? ?? '').trim().toLowerCase();
  return data['isBlocked'] == true ||
      data['blocked'] == true ||
      status == 'blocked' ||
      status == 'disabled';
}

bool _isAdminRecord(Map<String, dynamic> data) {
  final role = (data['role'] ?? data['userRole'] ?? data['accountType'])
      .toString()
      .trim()
      .toLowerCase();
  return role == 'admin' ||
      role == 'administrator' ||
      role == 'super_admin' ||
      role == 'superadmin' ||
      data['isAdmin'] == true ||
      data['admin'] == true;
}

bool _isActiveProduct(Map<String, dynamic> data) {
  return _text(data, 'status', fallback: '').toLowerCase() == 'active';
}

String? _productImageUrl(Map<String, dynamic> data) {
  final imageUrl = _text(data, 'imageUrl', fallback: '');
  if (imageUrl.isNotEmpty) return imageUrl;

  final images = data['images'];
  if (images is List) {
    for (final image in images) {
      if (image is String && image.trim().isNotEmpty) {
        return image.trim();
      }
    }
  }

  return null;
}

Color _productStatusColor(Map<String, dynamic> data) {
  final status = _text(data, 'status', fallback: '').toLowerCase();
  return switch (status) {
    'active' => Colors.green,
    'sold' => Colors.orange,
    _ => kSecondaryColor,
  };
}

BoxDecoration _adminCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFD8E3EE)),
    boxShadow: const [
      BoxShadow(color: Color(0x140E0820), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );
}
