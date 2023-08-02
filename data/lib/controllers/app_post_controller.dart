import 'dart:io';

import 'package:data/utils/app_response.dart';
import 'package:conduit_core/conduit_core.dart';
import 'package:data/models/author.dart';
import 'package:data/models/post.dart';
import 'package:data/utils/app_utils.dart';

class AppPostController extends ResourceController {
  final ManagedContext managedContext;

  AppPostController(this.managedContext);

  @Operation.post()
  Future<Response> createPosts(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Post post,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final author = await managedContext.fetchObjectWithID<Author>(id);
      if (author == null) {
        final qCreateAuthor = Query<Author>(managedContext)..values.id = id;
        await qCreateAuthor.insert();
      }
      final qCreatePost = Query<Post>(managedContext)
        ..values.author?.id = id
        ..values.content = post.content;
      await qCreatePost.insert();
      return AppResponse.ok(
        message: 'Успешное создание поста',
      );
    } catch (error) {
      return AppResponse.serverError(
        error,
        message: 'Ошибка создания поста',
      );
    }
  }

  @Operation.get('id')
  Future<Response> getPost(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.path('id') int id,
  ) async {
    try {
      final currentAuthorId = AppUtils.getIdFromHeader(header);
      final post = await managedContext.fetchObjectWithID<Post>(id);
      if (post == null) {
        return AppResponse.serverError(
          Error,
          message: 'Пост не найден',
        );
      }
      if (post.author?.id != currentAuthorId) {
        return AppResponse.serverError(
          Error,
          message: 'Нет доступа к посту',
        );
      }
      post.backing.removeProperty('author');
      return AppResponse.ok(
        body: post.backing.contents,
        message: 'Успешное получение своих постов',
      );
    } catch (error) {
      return AppResponse.serverError(
        error,
        message: 'Ошибка получения постов',
      );
    }
  }

  @Operation.delete('id')
  Future<Response> deletePost(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.path('id') int id,
  ) async {
    try {
      final currentAuthorId = AppUtils.getIdFromHeader(header);
      final post = await managedContext.fetchObjectWithID<Post>(id);
      if (post == null) {
        return AppResponse.serverError(
          Error,
          message: 'Пост не найден',
        );
      }
      if (post.author?.id != currentAuthorId) {
        return AppResponse.serverError(
          Error,
          message: 'Нет доступа к посту',
        );
      }
      final qDeletePost = Query<Post>(managedContext)
        ..where((x) => x.id).equalTo(id);
      await qDeletePost.delete();
      return AppResponse.ok(
        message: 'Успешное удаление поста',
      );
    } catch (error) {
      return AppResponse.serverError(
        error,
        message: 'Ошибка удаления поста',
      );
    }
  }

  @Operation.get()
  Future<Response> getPosts(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final qGetPosts = Query<Post>(managedContext)
        ..where((x) => x.author?.id).equalTo(id);
      final List<Post> posts = await qGetPosts.fetch();
      final backedPosts = posts.map((e) => e.asMap()).toList();
      if (posts.isEmpty) {
        return AppResponse.notFound(
          message: 'Постов нет',
        );
      }
      return AppResponse.ok(
        body: backedPosts,
        message: 'Успешно получено постов - ${backedPosts.length}',
      );
    } catch (error) {
      return AppResponse.serverError(
        error,
        message: 'Ошибка получения постов',
      );
    }
  }
}
