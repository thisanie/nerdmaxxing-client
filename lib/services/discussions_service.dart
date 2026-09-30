import '../models/discussion_comment.dart';
import 'api_client.dart';

class DiscussionsService {
  final ApiClient api;
  DiscussionsService(this.api);

  Future<DiscussionPage> list(String challengeSlug, {String? cursor}) async {
    final data = await api.get(
      '/challenges/$challengeSlug/discussions',
      query: {'cursor': ?cursor},
      skipAuth: true,
    );
    return _page(data);
  }

  Future<DiscussionComment> create(
    String challengeSlug, {
    required String body,
    String type = 'COMMENT',
  }) async {
    final data = await api.post(
      '/challenges/$challengeSlug/discussions',
      data: {'body': body, 'type': type},
    );
    return DiscussionComment.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DiscussionComment> get(String discussionId) async {
    final data = await api.get('/discussions/$discussionId', skipAuth: true);
    return DiscussionComment.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DiscussionComment> update(String discussionId, String body) async {
    final data = await api.patch(
      '/discussions/$discussionId',
      data: {'body': body},
    );
    return DiscussionComment.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(String discussionId) async {
    await api.delete('/discussions/$discussionId');
  }

  Future<DiscussionPage> listReplies(
    String discussionId, {
    String? cursor,
  }) async {
    final data = await api.get(
      '/discussions/$discussionId/replies',
      query: {'cursor': ?cursor},
      skipAuth: true,
    );
    return _page(data);
  }

  Future<DiscussionComment> reply(String discussionId, String body) async {
    final data = await api.post(
      '/discussions/$discussionId/replies',
      data: {'body': body},
    );
    return DiscussionComment.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<DiscussionComment> updateReply(
    String discussionId,
    String replyId,
    String body,
  ) async {
    final data = await api.patch(
      '/discussions/$discussionId/replies/$replyId',
      data: {'body': body},
    );
    return DiscussionComment.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteReply(String discussionId, String replyId) async {
    await api.delete('/discussions/$discussionId/replies/$replyId');
  }

  Future<void> resolve(String discussionId) async {
    await api.patch('/discussions/$discussionId/resolve');
  }

  Future<void> report(
    String discussionId, {
    String? replyId,
    String reason = 'OTHER',
  }) async {
    final path = replyId == null
        ? '/discussions/$discussionId/report'
        : '/discussions/$discussionId/replies/$replyId/report';
    await api.post(path, data: {'reason': reason});
  }

  DiscussionPage _page(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    final items = (map['items'] as List? ?? const [])
        .map(
          (item) => DiscussionComment.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return DiscussionPage(
      items: items,
      nextCursor: map['next_cursor']?.toString(),
    );
  }
}
