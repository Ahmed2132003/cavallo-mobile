/// New feature scope (Part P-033, STEP 6): the clean domain
/// representation of a single node in the category tree returned by
/// `GET /api/v1/categories/tree/` (Part P-025).
///
/// ### Deliberate deviation from Part P-001's fixed feature list
///
/// Part P-001's Section 12 folder skeleton pre-created a fixed set of
/// feature folders (`auth`, `feed`, `stories`, `search`,
/// `business_profile`, `products`, `chat`, `notifications`,
/// `business_console`) — `categories` was NOT one of them. Both
/// P-025's own handoff note and P-028A's own handoff note flagged this
/// explicitly: "no Flutter categories feature/provider exists yet
/// anywhere in the app." This part is the first to actually need one
/// (the product create/edit form's category picker), so
/// `lib/features/categories/` is created fresh here, following the
/// exact same `{data, domain, presentation}` internal shape every
/// other feature folder already uses — not a new organizational
/// pattern, just a new feature.
library;

/// A single category, with its full subtree already nested inline —
/// exactly as `build_category_tree()` (backend, `categories/services.py`)
/// returns it. There is no separate "flat category" entity: the tree
/// shape is the only shape this endpoint ever returns, and this part's
/// own spec explicitly allows rendering it as "a simple flattened
/// dropdown with indentation" — that flattening is a presentation-layer
/// concern (a future step's picker widget), not something this entity
/// does itself.
class CategoryNode {
  const CategoryNode({
    required this.id,
    required this.name,
    required this.slug,
    this.children = const [],
  });

  final int id;
  final String name;
  final String slug;

  /// Nested child categories, in the exact order the backend returned
  /// them (already `order_by("name")` server-side — no re-sorting
  /// needed here).
  final List<CategoryNode> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryNode &&
          other.id == id &&
          other.name == name &&
          other.slug == slug &&
          _childrenEqual(other.children, children));

  static bool _childrenEqual(List<CategoryNode> a, List<CategoryNode> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, name, slug, Object.hashAll(children));

  @override
  String toString() =>
      'CategoryNode(id: $id, name: $name, slug: $slug, '
      'children: ${children.length})';
}