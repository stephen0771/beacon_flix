import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

const String tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');

const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/';

/// Full-length movie source.
/// This is a public-domain copy of His Girl Friday.
const String hisGirlFridayVideo =
    'https://archive.org/download/his_girl_friday/his_girl_friday_512kb.mp4';

void main() {
  runApp(const BeaconFlixApp());
}

// ============================================================
// APP
// ============================================================

class BeaconFlixApp extends StatelessWidget {
  const BeaconFlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeaconFlix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080808),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================================================
// MOVIE MODEL
// ============================================================

class Movie {
  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String releaseDate;
  final double rating;
  final List<int> genreIds;
  final String? videoUrl;
  final bool isLegal;

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.releaseDate,
    required this.rating,
    required this.genreIds,
    this.videoUrl,
    this.isLegal = false,
  });

  factory Movie.fromJson(
    Map<String, dynamic> json, {
    String? videoUrl,
    bool isLegal = false,
  }) {
    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown Movie',
      overview: json['overview'] ?? 'No description available.',
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      releaseDate: json['release_date'] ?? '',
      rating: (json['vote_average'] ?? 0).toDouble(),
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      videoUrl: videoUrl,
      isLegal: isLegal,
    );
  }

  String get posterUrl {
    if (posterPath == null) return '';
    return '$tmdbImageBaseUrl/w500$posterPath';
  }

  String get backdropUrl {
    if (backdropPath == null) return '';
    return '$tmdbImageBaseUrl/original$backdropPath';
  }

  String get year {
    if (releaseDate.length >= 4) {
      return releaseDate.substring(0, 4);
    }
    return '';
  }
}

// ============================================================
// LEGAL MOVIE
// ============================================================

class LegalMovieSource {
  final String title;
  final int year;
  final String videoUrl;

  const LegalMovieSource({
    required this.title,
    required this.year,
    required this.videoUrl,
  });
}

const List<LegalMovieSource> legalMovieSources = [
  LegalMovieSource(
    title: 'His Girl Friday',
    year: 1940,
    videoUrl: hisGirlFridayVideo,
  ),
];

// ============================================================
// TMDB SERVICE
// ============================================================

class TmdbService {
  Future<List<Movie>> getTrendingMovies() async {
    if (tmdbApiKey.isEmpty) {
      throw Exception(
        'TMDB API key missing. Run the app with --dart-define=TMDB_API_KEY=YOUR_KEY',
      );
    }

    final uri = Uri.parse(
      '$tmdbBaseUrl/trending/movie/week'
      '?api_key=$tmdbApiKey'
      '&language=en-US',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'TMDB error: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    final List results = data['results'] ?? [];

    return results
        .map((movie) => Movie.fromJson(movie))
        .toList();
  }

  Future<Movie?> searchMovie(
    String title,
    int year, {
    String? videoUrl,
    bool isLegal = false,
  }) async {
    if (tmdbApiKey.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      '$tmdbBaseUrl/search/movie'
      '?api_key=$tmdbApiKey'
      '&language=en-US'
      '&query=${Uri.encodeQueryComponent(title)}'
      '&year=$year',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);
    final List results = data['results'] ?? [];

    if (results.isEmpty) {
      return null;
    }

    return Movie.fromJson(
      results.first,
      videoUrl: videoUrl,
      isLegal: isLegal,
    );
  }

  Future<List<Movie>> getLegalMovies() async {
    final List<Movie> movies = [];

    for (final source in legalMovieSources) {
      final movie = await searchMovie(
        source.title,
        source.year,
        videoUrl: source.videoUrl,
        isLegal: true,
      );

      if (movie != null) {
        movies.add(movie);
      }
    }

    return movies;
  }
}

// ============================================================
// CATEGORIES
// ============================================================

class Category {
  final String name;
  final int? genreId;

  const Category(this.name, this.genreId);
}

const List<Category> categories = [
  Category('Home', null),
  Category('Movies', null),
  Category('Adventure', 12),
  Category('Action', 28),
  Category('Comedy', 35),
  Category('Drama', 18),
  Category('Sci-Fi', 878),
  Category('Horror', 27),
  Category('Romance', 10749),
  Category('Animation', 16),
  Category('Kids', 10751),
  Category('Cinemas', null),
  Category('My List', null),
];

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TmdbService service = TmdbService();

  int selectedCategory = 0;

  List<Movie> trendingMovies = [];
  List<Movie> legalMovies = [];
  List<Movie> myList = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadMovies();
  }

  Future<void> loadMovies() async {
    try {
      final trending = await service.getTrendingMovies();
      final legal = await service.getLegalMovies();

      if (!mounted) return;

      setState(() {
        trendingMovies = trending;
        legalMovies = legal;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  List<Movie> get filteredMovies {
    final category = categories[selectedCategory];

    if (category.name == 'Home') {
      return trendingMovies;
    }

    if (category.name == 'Movies') {
      return trendingMovies;
    }

    if (category.name == 'My List') {
      return myList;
    }

    if (category.name == 'Cinemas') {
      return legalMovies;
    }

    if (category.genreId != null) {
      return trendingMovies
          .where(
            (movie) => movie.genreIds.contains(category.genreId),
          )
          .toList();
    }

    return trendingMovies;
  }

  String get categoryTitle {
    return categories[selectedCategory].name;
  }

  void toggleMyList(Movie movie) {
    setState(() {
      final exists = myList.any((item) => item.id == movie.id);

      if (exists) {
        myList.removeWhere((item) => item.id == movie.id);
      } else {
        myList.add(movie);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: loadMovies,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildHeader(),
                        ),

                        SliverToBoxAdapter(
                          child: _buildCategoryBar(),
                        ),

                        SliverToBoxAdapter(
                          child: _buildHero(),
                        ),

                        SliverToBoxAdapter(
                          child: _buildLegalMovies(),
                        ),

                        SliverToBoxAdapter(
                          child: _buildSectionTitle(
                            categoryTitle,
                          ),
                        ),

                        _buildMovieGrid(),

                        SliverToBoxAdapter(
                          child: const SizedBox(height: 50),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load BeaconFlix',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error ?? '',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                setState(() {
                  loading = true;
                  error = null;
                });

                loadMovies();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          const Icon(
            Icons.play_circle_fill,
            color: Colors.red,
            size: 38,
          ),
          const SizedBox(width: 10),
          const Text(
            'BeaconFlix',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              showSearch(
                context: context,
                delegate: MovieSearchDelegate(
                  movies: [
                    ...trendingMovies,
                    ...legalMovies,
                  ],
                ),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedCategory = categories.indexWhere(
                  (category) => category.name == 'My List',
                );
              });
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // TOP CATEGORY MENU
  // ==========================================================

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final selected = index == selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(categories[index].name),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  selectedCategory = index;
                });
              },
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white70,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              selectedColor: Colors.red,
              backgroundColor: const Color(0xFF1B1B1B),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // HERO
  // ==========================================================

  Widget _buildHero() {
    final movies = selectedCategory == 0
        ? trendingMovies
        : filteredMovies;

    if (movies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(
              Icons.movie_outlined,
              size: 50,
            ),
            const SizedBox(height: 10),
            Text(
              'No movies found in $categoryTitle yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final movie = movies.first;

    return GestureDetector(
      onTap: () {
        _openDetails(movie);
      },
      child: Container(
        height: 430,
        margin: const EdgeInsets.fromLTRB(
          14,
          14,
          14,
          24,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: movie.backdropPath != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(
                    movie.backdropUrl,
                  ),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0xFF080808),
              ],
            ),
          ),
          padding: const EdgeInsets.all(22),
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (movie.isLegal)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'FREE & LEGAL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                movie.title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${movie.year}  •  ⭐ ${movie.rating.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                movie.overview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      _openDetails(movie);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      movie.videoUrl != null
                          ? 'Watch Now'
                          : 'Details',
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      toggleMyList(movie);
                    },
                    icon: Icon(
                      myList.any(
                        (item) => item.id == movie.id,
                      )
                          ? Icons.check
                          : Icons.add,
                    ),
                    label: const Text('My List'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // LEGAL MOVIES
  // ==========================================================

  Widget _buildLegalMovies() {
    if (legalMovies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Free & Legal Movies'),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: legalMovies.length,
            itemBuilder: (context, index) {
              final movie = legalMovies[index];

              return _buildMovieCard(
                movie,
                width: 155,
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // SECTION TITLE
  // ==========================================================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        24,
        16,
        12,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================================
  // MOVIE GRID
  // ==========================================================

  Widget _buildMovieGrid() {
    final movies = filteredMovies;

    if (movies.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              'No movies available here yet.',
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildMovieCard(
              movies[index],
              width: double.infinity,
            );
          },
          childCount: movies.length,
        ),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 18,
          childAspectRatio: 0.62,
        ),
      ),
    );
  }

  // ==========================================================
  // MOVIE CARD
  // ==========================================================

  Widget _buildMovieCard(
    Movie movie, {
    required double width,
  }) {
    return GestureDetector(
      onTap: () {
        _openDetails(movie);
      },
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: movie.posterUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: movie.posterUrl,
                        width: width,
                        fit: BoxFit.cover,
                        placeholder: (context, url) {
                          return Container(
                            color: const Color(0xFF202020),
                            child: const Center(
                              child:
                                  CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorWidget:
                            (context, url, error) {
                          return Container(
                            color: const Color(0xFF202020),
                            child: const Icon(
                              Icons.movie,
                              size: 40,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: const Color(0xFF202020),
                        child: const Icon(
                          Icons.movie,
                          size: 40,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${movie.year}  •  ⭐ ${movie.rating.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieDetailsScreen(
          movie: movie,
          onToggleList: () {
            toggleMyList(movie);
          },
          inMyList: myList.any(
            (item) => item.id == movie.id,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MOVIE DETAILS
// ============================================================

class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;
  final VoidCallback onToggleList;
  final bool inMyList;

  const MovieDetailsScreen({
    super.key,
    required this.movie,
    required this.onToggleList,
    required this.inMyList,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(
              color: Colors.white,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: movie.backdropUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: movie.backdropUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black,
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (movie.isLegal)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'FREE & LEGAL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  Text(
                    movie.title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${movie.year}  •  ⭐ ${movie.rating.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white60,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: movie.videoUrl != null
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          VideoPlayerScreen(
                                        title: movie.title,
                                        videoUrl:
                                            movie.videoUrl!,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(
                            Icons.play_arrow,
                          ),
                          label: Text(
                            movie.videoUrl != null
                                ? 'Watch Now'
                                : 'No Stream Available',
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      IconButton(
                        onPressed: onToggleList,
                        style: IconButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF222222),
                        ),
                        icon: Icon(
                          inMyList
                              ? Icons.check
                              : Icons.add,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    movie.overview,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.6,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (movie.isLegal)
                    const Text(
                      'This movie is being provided from an '
                      'authorized public-domain source. '
                      'Rights can vary by country, so verify '
                      'distribution rights before commercial release.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),

                  const SizedBox(height: 40),

                  const Text(
                    'Movie information provided by TMDB.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VIDEO PLAYER
// ============================================================

class VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String videoUrl;

  const VideoPlayerScreen({
    super.key,
    required this.title,
    required this.videoUrl,
  });

  @override
  State<VideoPlayerScreen> createState() =>
      _VideoPlayerScreenState();
}

class _VideoPlayerScreenState
    extends State<VideoPlayerScreen> {
  late VideoPlayerController controller;

  bool initialized = false;
  String? error;

  @override
  void initState() {
    super.initState();
    initializeVideo();
  }

  Future<void> initializeVideo() async {
    try {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        initialized = true;
      });

      await controller.play();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    if (initialized) {
      controller.dispose();
    }

    super.dispose();
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
      ),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 55,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Unable to play this movie.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : !initialized
              ? const Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Loading movie...',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: ValueListenableBuilder<
                      VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (
                      context,
                      value,
                      child,
                    ) {
                      return Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio:
                                value.aspectRatio,
                            child: VideoPlayer(
                              controller,
                            ),
                          ),

                          const SizedBox(height: 15),

                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 15,
                            ),
                            child: VideoProgressIndicator(
                              controller,
                              allowScrubbing: true,
                              padding:
                                  const EdgeInsets.all(8),
                            ),
                          ),

                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 22,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  formatDuration(
                                    value.position,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formatDuration(
                                    value.duration,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          IconButton(
                            iconSize: 55,
                            onPressed: () {
                              if (controller.value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                            },
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

// ============================================================
// SEARCH
// ============================================================

class MovieSearchDelegate extends SearchDelegate<Movie?> {
  final List<Movie> movies;

  MovieSearchDelegate({
    required this.movies,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
          },
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = movies.where((movie) {
      return movie.title
          .toLowerCase()
          .contains(query.toLowerCase());
    }).toList();

    return _buildResults(context, results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = movies.where((movie) {
      return movie.title
          .toLowerCase()
          .contains(query.toLowerCase());
    }).toList();

    return _buildResults(context, results);
  }

  Widget _buildResults(
    BuildContext context,
    List<Movie> results,
  ) {
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No movies found.',
          style: TextStyle(
            color: Colors.white54,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final movie = results[index];

        return ListTile(
          leading: movie.posterUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: movie.posterUrl,
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.movie),
          title: Text(movie.title),
          subtitle: Text(movie.year),
          onTap: () {
            close(context, movie);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovieDetailsScreen(
                  movie: movie,
                  onToggleList: () {},
                  inMyList: false,
                ),
              ),
            );
          },
        );
      },
    );
  }
}