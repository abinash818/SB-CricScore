import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://sbastro.com/tournament/api';
  // static const String baseUrl = 'http://127.0.0.1:8080/api'; // For local testing

  final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    validateStatus: (status) => status != null && status < 500,
    headers: {
      'Accept': 'application/json',
    },
  ));

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  static String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final root = baseUrl.replaceAll('/api', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$root/$cleanPath';
  }

  ApiService() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 401) {
          storage.delete(key: 'auth_token');
        }
        return handler.next(e);
      },
    ));
  }

  // ── Send OTP ──
  Future<Map<String, dynamic>> sendOtp(String mobile) async {
    final response = await dio.post('/otp_send.php', data: {'mobile': mobile});
    return response.data;
  }

  // ── Verify OTP ──
  Future<Map<String, dynamic>> verifyOtp(String mobile, String otp) async {
    final response = await dio.post('/otp_verify.php', data: {
      'mobile': mobile,
      'otp': otp,
    });
    if (response.data['success'] == true && response.data['token'] != null) {
      await storage.write(key: 'auth_token', value: response.data['token']);
    }
    return response.data;
  }

  // ── Resend OTP ──
  Future<Map<String, dynamic>> resendOtp(String mobile) async {
    final response = await dio.post('/otp_resend.php', data: {'mobile': mobile});
    return response.data;
  }

  // ── Fetch Profile ──
  Future<Map<String, dynamic>> getProfile() async {
    final response = await dio.get('/profile_get.php');
    return response.data;
  }

  // ── Update Profile (with photo upload) ──
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String city,
    String? dob,
    String? battingStyle,
    String? bowlingStyle,
    String? role,
    String? jerseyNumber,
    String? preferredFormat,
    String? imagePath,
    List<int>? imageBytes,
    String? imageName,
  }) async {
    MultipartFile? picFile;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      picFile = MultipartFile.fromBytes(imageBytes, filename: imageName ?? 'profile.jpg');
    } else if (imagePath != null && imagePath.isNotEmpty) {
      picFile = await MultipartFile.fromFile(imagePath, filename: imageName ?? 'profile.jpg');
    }

    final formData = FormData.fromMap({
      'name': name,
      'city': city,
      if (dob != null) 'dob': dob,
      if (battingStyle != null) 'batting_style': battingStyle,
      if (bowlingStyle != null) 'bowling_style': bowlingStyle,
      if (role != null) 'role': role,
      if (jerseyNumber != null) 'jersey_number': jerseyNumber,
      if (preferredFormat != null) 'preferred_format': preferredFormat,
      if (picFile != null) 'profile_pic': picFile,
    });

    final response = await dio.post('/profile_update.php', data: formData);
    return response.data;
  }

  // ── Logout ──
  Future<void> logout() async {
    try {
      await dio.post('/app_logout.php');
    } catch (_) {}
    await storage.delete(key: 'auth_token');
  }

  // ── Tournaments ──
  Future<Map<String, dynamic>> getTournaments({String? search, String? district, String? state}) async {
    final response = await dio.get('/tournament_ops.php', queryParameters: {
      'action': 'list',
      if (search != null && search.isNotEmpty) 'q': search,
      if (district != null && district.isNotEmpty) 'district': district,
      if (state != null && state.isNotEmpty) 'state': state,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getTournamentHub(int tournamentId) async {
    final response = await dio.get('/tournament_ops.php', queryParameters: {
      'action': 'get',
      'tournament_id': tournamentId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> createTournament({
    required String name,
    String type = 'round_robin',
    int winPoints = 2,
    int tiePoints = 1,
    int nrPoints = 1,
    int lossPoints = 0,
    int defaultOvers = 20,
    int defaultWickets = 10,
    List<String>? teams,
  }) async {
    final response = await dio.post('/tournament_ops.php?action=create', data: {
      'name': name,
      'type': type,
      'win_points': winPoints,
      'tie_points': tiePoints,
      'nr_points': nrPoints,
      'loss_points': lossPoints,
      'default_overs': defaultOvers,
      'default_wickets': defaultWickets,
      if (teams != null) 'teams': teams,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> generateFixtures({
    required int tournamentId,
    String type = 'single',
    int oversLimit = 20,
  }) async {
    final response = await dio.post('/tournament_ops.php?action=generate_fixtures', data: {
      'tournament_id': tournamentId,
      'type': type,
      'overs_limit': oversLimit,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getTournamentStats(int tournamentId) async {
    final response = await dio.get('/stats.php', queryParameters: {
      'tournament_id': tournamentId,
    });
    return response.data;
  }

  // ── Universal Search ──
  Future<Map<String, dynamic>> searchGlobal(String query, {String type = 'all'}) async {
    final response = await dio.get('/search_ops.php', queryParameters: {
      'q': query,
      'type': type,
    });
    return response.data;
  }

  // ── Notifications ──
  Future<Map<String, dynamic>> getNotifications() async {
    final response = await dio.get('/notifications_ops.php', queryParameters: {'action': 'list'});
    return response.data;
  }

  Future<Map<String, dynamic>> markNotificationRead({int? notificationId}) async {
    final response = await dio.post('/notifications_ops.php?action=read', data: {
      if (notificationId != null) 'notification_id': notificationId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> savePushToken(String token) async {
    final response = await dio.post('/notifications_ops.php?action=save_token', data: {
      'token': token,
    });
    return response.data;
  }

  // ── Community Feed ──
  Future<Map<String, dynamic>> getFeed({String category = 'all', int page = 1}) async {
    final response = await dio.get('/feed_ops.php', queryParameters: {
      'action': 'list',
      'category': category,
      'page': page,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> createFeedPost({
    required String content,
    String postType = 'general',
    String? whatsappNumber,
    MultipartFile? imageFile,
    String? imagePath,
    List<int>? imageBytes,
    String? imageName,
  }) async {
    MultipartFile? picFile = imageFile;
    if (picFile == null) {
      if (imageBytes != null && imageBytes.isNotEmpty) {
        picFile = MultipartFile.fromBytes(imageBytes, filename: imageName ?? 'feed.jpg');
      } else if (imagePath != null && imagePath.isNotEmpty) {
        picFile = await MultipartFile.fromFile(imagePath, filename: imageName ?? 'feed.jpg');
      }
    }

    final formData = FormData.fromMap({
      'content': content,
      'post_type': postType,
      if (whatsappNumber != null && whatsappNumber.isNotEmpty) 'whatsapp_number': whatsappNumber,
      if (picFile != null) 'image': picFile,
    });

    final response = await dio.post('/feed_ops.php?action=create', data: formData);
    return response.data;
  }

  Future<Map<String, dynamic>> toggleFeedLike(int postId) async {
    final response = await dio.post('/feed_ops.php?action=like', data: {'post_id': postId});
    return response.data;
  }

  Future<Map<String, dynamic>> deleteFeedPost(int postId) async {
    final response = await dio.post('/feed_ops.php?action=delete', data: {'post_id': postId});
    return response.data;
  }


  // ── Social Share ──
  Future<Map<String, dynamic>> getMatchShareSummary(int matchId) async {
    final response = await dio.get('/share_ops.php', queryParameters: {
      'action': 'match_share',
      'match_id': matchId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getTournamentShareSummary(int tournamentId) async {
    final response = await dio.get('/share_ops.php', queryParameters: {
      'action': 'tournament_share',
      'tournament_id': tournamentId,
    });
    return response.data;
  }

  // ── Live Video Stream ──
  Future<Map<String, dynamic>> updateMatchStream(int matchId, String youtubeUrl, {int isActive = 1}) async {
    final response = await dio.post('/match_stream_update.php', data: {
      'match_id': matchId,
      'youtube_url': youtubeUrl,
      'is_active': isActive,
    });
    return response.data;
  }

  // ── Captain Register Player ──
  Future<Map<String, dynamic>> captainRegisterPlayer({
    required int teamId,
    required String name,
    required String mobile,
    String? otp,
    String role = 'BAT',
    String battingStyle = 'Right Hand Bat',
    String bowlingStyle = 'Right Arm Medium',
    String jerseyNumber = '',
    bool skipOtp = false,
    int? sourcePlayerId,
  }) async {
    final response = await dio.post('/captain_register_player.php', data: {
      'team_id': teamId,
      'name': name,
      'mobile': mobile,
      if (otp != null) 'otp': otp,
      'role': role,
      'batting_style': battingStyle,
      'bowling_style': bowlingStyle,
      'jersey_number': jerseyNumber,
      'skip_otp': skipOtp,
      if (sourcePlayerId != null && sourcePlayerId > 0) 'source_player_id': sourcePlayerId,
    });
    return response.data;
  }

  // ── Playing XI + Substitutes (11+3) ──
  Future<Map<String, dynamic>> getPlayingXI(int matchId) async {
    final response = await dio.get('/match_playing_xi.php', queryParameters: {'match_id': matchId});
    return response.data;
  }

  Future<Map<String, dynamic>> savePlayingXI({
    required int matchId,
    required int teamId,
    required List<int> playingXiIds,
    List<int> substituteIds = const [],
    int? captainId,
    int? wicketkeeperId,
  }) async {
    final response = await dio.post('/match_playing_xi.php', data: {
      'match_id': matchId,
      'team_id': teamId,
      'playing_xi_ids': playingXiIds,
      'substitute_ids': substituteIds,
      if (captainId != null) 'captain_id': captainId,
      if (wicketkeeperId != null) 'wicketkeeper_id': wicketkeeperId,
    });
    return response.data;
  }

  // ── Team Name Availability ──
  Future<Map<String, dynamic>> checkTeamNameAvailability(String name) async {
    final response = await dio.get('/team_ops.php', queryParameters: {
      'action': 'check_name',
      'name': name,
    });
    return response.data;
  }

  // ── Create User Team ──
  Future<Map<String, dynamic>> createUserTeam({
    required String name,
    String? shortName,
    String? city,
    String icon = 'shield',
    int? ownerId,
    int? tournamentId,
    bool addCaptain = true,
    String? creatorName,
    String? creatorMobile,
    String? creatorRole,
    String? creatorBattingStyle,
    String? creatorBowlingStyle,
    String? creatorJersey,
  }) async {
    final response = await dio.post('/team_ops.php?action=create_user_team', data: {
      'name': name,
      if (shortName != null) 'short_name': shortName,
      if (city != null) 'city': city,
      'icon': icon,
      if (ownerId != null) 'owner_id': ownerId,
      if (tournamentId != null) 'tournament_id': tournamentId,
      'add_captain': addCaptain,
      if (creatorName != null) 'creator_name': creatorName,
      if (creatorMobile != null) 'creator_mobile': creatorMobile,
      if (creatorRole != null) 'creator_role': creatorRole,
      if (creatorBattingStyle != null) 'creator_batting_style': creatorBattingStyle,
      if (creatorBowlingStyle != null) 'creator_bowling_style': creatorBowlingStyle,
      if (creatorJersey != null) 'creator_jersey': creatorJersey,
    });
    return response.data;
  }

  // ── Get My Teams ──
  Future<Map<String, dynamic>> getMyTeams({
    int? ownerId,
    int? playerId,
    String? mobile,
    String? playerName,
  }) async {
    final response = await dio.get('/team_ops.php', queryParameters: {
      'action': 'my_teams',
      if (ownerId != null) 'owner_id': ownerId,
      if (playerId != null) 'player_id': playerId,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      if (playerName != null && playerName.isNotEmpty) 'player_name': playerName,
    });
    return response.data;
  }

  // ── Search Players by Mobile Phone or Name ──
  Future<Map<String, dynamic>> searchPlayersByPhoneOrName(String query) async {
    final response = await dio.get('/team_ops.php', queryParameters: {
      'action': 'search_players',
      'q': query,
    });
    return response.data;
  }

  // ── Join Match via QR / Code ──
  Future<Map<String, dynamic>> joinMatchQR({
    required int teamId,
    String? matchCode,
    int? matchId,
    List<int>? playerIds,
  }) async {
    final response = await dio.post('/match_join_qr.php', data: {
      'team_id': teamId,
      if (matchCode != null) 'match_code': matchCode,
      if (matchId != null) 'match_id': matchId,
      if (playerIds != null) 'player_ids': playerIds,
    });
    return response.data;
  }

  // ── Set Captain / Leader ──
  Future<Map<String, dynamic>> setCaptain(int teamId, int playerId) async {
    final response = await dio.post('/team_ops.php?action=set_captain', data: {
      'team_id': teamId,
      'player_id': playerId,
    });
    return response.data;
  }

  // ── Set Clan / Team Role (Leader, Co-Leader, Member) ──
  Future<Map<String, dynamic>> setClanRole(int teamId, int playerId, String role) async {
    final response = await dio.post('/team_ops.php?action=set_clan_role', data: {
      'team_id': teamId,
      'player_id': playerId,
      'role': role,
    });
    return response.data;
  }

  // ── Remove Player from Squad ──
  Future<Map<String, dynamic>> removePlayer(int teamId, int playerId) async {
    final response = await dio.post('/team_ops.php?action=remove_player', data: {
      'team_id': teamId,
      'player_id': playerId,
    });
    return response.data;
  }
}


