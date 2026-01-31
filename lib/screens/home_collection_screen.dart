import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/anime_model.dart';
import '../providers/anime_provider.dart';
import '../widgets/anime_card.dart';
import '../constants/app_colors.dart';

class HomeCollectionScreen extends StatefulWidget {
  final HomeCollectionType type;

  const HomeCollectionScreen({super.key, required this.type});

  @override
  State<HomeCollectionScreen> createState() => _HomeCollectionScreenState();
}

class _HomeCollectionScreenState extends State<HomeCollectionScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Anime> _animes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final cached =
        Provider.of<AnimeProvider>(context, listen: false).getHomeCollectionSnapshot(widget.type);
    if (cached.isNotEmpty) {
      _animes.addAll(cached);
      _hasMore = cached.length >= 16;
      _isLoading = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPage(1, replace: cached.isEmpty);
    });
  }

  Future<void> _fetchPage(int page, {bool replace = false}) async {
    if (page == 1) {
      setState(() {
        _isLoading = replace;
        _errorMessage = null;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() {
        _isLoadingMore = true;
        _errorMessage = null;
      });
    }

    try {
      final provider = Provider.of<AnimeProvider>(context, listen: false);
      final resultData = await provider.fetchHomeCollectionPage(widget.type, page: page);
      
      final result = resultData['animes'] as List<Anime>;
      final pagination = resultData['pagination'] as Map<String, dynamic>;

      setState(() {
        if (page == 1) {
          _animes
            ..clear()
            ..addAll(result);
        } else {
          final existingIds = _animes.map((a) => a.id).toSet();
          final filtered = result.where((anime) => !existingIds.contains(anime.id));
          _animes.addAll(filtered);
        }

        _currentPage = pagination['currentPage'] ?? page;
        _hasMore = pagination['hasNextPage'] ?? false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Tidak dapat memuat data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchPage(1, replace: true);
  }

  void _loadMore() {
    if (_hasMore && !_isLoadingMore) {
      _fetchPage(_currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          backgroundColor: AppColors.cardBg,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.background,
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.4),
                toolbarHeight: 72,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.type.title,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.type.description,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => _fetchPage(1, replace: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),

              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFEF4444).withValues(alpha: 0.1),
                          const Color(0xFF991B1B).withValues(alpha: 0.1),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFFCA5A5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFCA5A5),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_isLoading && _animes.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                )
              else if (_animes.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada data',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 20,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _animes.length - 2 && _hasMore && !_isLoadingMore) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _loadMore();
                          });
                        }
                        return AnimeCard(anime: _animes[index]);
                      },
                      childCount: _animes.length,
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          )
                        : _hasMore
                            ? ElevatedButton(
                                onPressed: _loadMore,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'Load More',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                              )
                            : Text(
                                'Semua data sudah ditampilkan',
                                style: GoogleFonts.inter(color: const Color(0xFF64748B)),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}



