import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../services/offline_cache_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/offline_banner.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<CourseModel> _courses = [];
  List<CategoryModel> _categories = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _selectedCategory = '';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchCtrl.text != _search) {
      setState(() => _search = _searchCtrl.text);
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    // Serve from cache when offline
    if (!OfflineCacheService.instance.isOnline &&
        _searchCtrl.text.isEmpty && _selectedCategory.isEmpty) {
      final cached = OfflineCacheService.instance.getCourses();
      if (cached != null) {
        setState(() { _courses = cached; _loading = false; });
        return;
      }
    }

    try {
      final data = await api.getCourses(
        search: _searchCtrl.text.trim(),
        category: _selectedCategory,
      );
      final courses = (data['courses'] as List? ?? [])
          .map((c) => CourseModel.fromJson(c)).toList();
      final cats = (data['categories'] as List? ?? [])
          .map((c) => CategoryModel.fromJson(c)).toList();

      // Cache the unfiltered list
      if (_searchCtrl.text.isEmpty && _selectedCategory.isEmpty) {
        await OfflineCacheService.instance.saveCourses(courses);
      }

      setState(() {
        _courses = courses;
        if (cats.isNotEmpty) _categories = cats;
        _loading = false;
      });
    } on ApiException catch (e) {
      final cached = OfflineCacheService.instance.getCourses();
      if (cached != null) {
        setState(() { _courses = cached; _loading = false; });
      } else {
        setState(() { _error = e.message; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sage50,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.sage800,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _HeroBanner(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Container(
                color: AppColors.sage800,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _SearchBar(controller: _searchCtrl, onSearch: _load),
              ),
            ),
          ),

          // Category chips
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.sage800,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.sage50,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: _CategoryChips(
                    categories: _categories,
                    selected: _selectedCategory,
                    onSelect: (id) {
                      setState(() => _selectedCategory = id == _selectedCategory ? '' : id);
                      _load();
                    },
                  ),
                ),
              ),
            ),
        ],
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _CourseGrid(courses: const [], loading: true);
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    if (_courses.isEmpty) return const EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No courses found',
      subtitle: 'Try different search terms or clear filters.',
    );
    return RefreshIndicator(
      color: AppColors.sage600,
      onRefresh: _load,
      child: _CourseGrid(courses: _courses, loading: false),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 24, right: 24, bottom: 8,
    ),
    decoration: const BoxDecoration(color: AppColors.sage800),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Explore', style: AppTextStyles.label.copyWith(color: AppColors.sage400, letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text(
          'Yoga Courses',
          style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 32, color: Colors.white),
        ),
      ],
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onSubmitted: (_) => onSearch(),
    style: AppTextStyles.body.copyWith(color: AppColors.sage900),
    decoration: InputDecoration(
      hintText: 'Search courses…',
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
      suffixIcon: controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.grey400),
              onPressed: () { controller.clear(); onSearch(); },
            )
          : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sage400, width: 1.5),
      ),
    ),
  );
}

class _CategoryChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selected;
  final void Function(String) onSelect;
  const _CategoryChips({required this.categories, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: categories.map((c) {
        final isSelected = selected == '${c.id}';
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelect('${c.id}'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.sage700 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.sage700 : AppColors.sage200),
              ),
              child: Text(
                c.name,
                style: AppTextStyles.body.copyWith(
                  color: isSelected ? Colors.white : AppColors.sage700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _CourseGrid extends StatelessWidget {
  final List<CourseModel> courses;
  final bool loading;
  const _CourseGrid({required this.courses, required this.loading});

  @override
  Widget build(BuildContext context) {
    final items = loading ? List.generate(6, (_) => null) : courses.cast<CourseModel?>();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => loading
          ? _SkeletonCourseCard()
          : _CourseCard(course: items[i]!),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CourseImage(url: course.banner, title: course.title, height: 110),
              if (course.hasDiscount)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warm500,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${course.discountPercent}% off',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: AppTextStyles.h3.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (course.plan != null) ...[
                    AppBadge(label: course.plan!),
                    const SizedBox(height: 6),
                  ],
                  PriceWidget(price: course.price, discountedPrice: course.discountedPrice, fontSize: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SkeletonCourseCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.sage100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(width: double.infinity, height: 110, radius: 0),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: double.infinity, height: 12),
              const SizedBox(height: 6),
              SkeletonBox(width: 80, height: 12),
              const SizedBox(height: 12),
              SkeletonBox(width: 60, height: 20),
            ],
          ),
        ),
      ],
    ),
  );
}
