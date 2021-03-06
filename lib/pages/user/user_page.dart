///
/// [Author] Alex (https://github.com/AlexV525)
/// [Date] 2020/7/24 13:40
///
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:loading_more_list/loading_more_list.dart';
import 'package:pull_to_refresh_notification/pull_to_refresh_notification.dart';

import 'package:openjmu/constants/constants.dart';
import 'package:openjmu/widgets/cards/post_card.dart';

@FFRoute(
  name: 'openjmu://user-page',
  routeName: '用户页',
  argumentNames: <String>['uid'],
  argumentTypes: <String>['int'],
)
class UserPage extends StatefulWidget {
  const UserPage({
    Key key,
    @required this.uid,
  }) : super(key: key);

  final int uid;

  @override
  UserPageState createState() => UserPageState();
}

class UserPageState extends State<UserPage>
    with SingleTickerProviderStateMixin {
  final ScrollController scrollController = ScrollController();

  final StreamController<bool> titleAnimateStreamController =
      StreamController<bool>.broadcast();

  final List<String> tabList = <String>['动态', '黑名单'];

  final List<UserTag> userTags = <UserTag>[];

  double get tabBarHeight => 56.h;

  TabController tabController;

  UserLevelScore userLevelScore;

  int userFans, userIdols;

  int get uid => widget.uid ?? currentUser.uid;

  bool get isCurrentUser => uid == currentUser.uid;

  double get expandedHeight =>
      Screens.width / 1.25 + (isCurrentUser ? tabBarHeight : 0.0);

  Stream<bool> get titleAnimateStream => titleAnimateStreamController.stream;

  UserInfo user;

  LoadingBase loadingBase;

  ListConfig<Map<String, dynamic>> listConfig;

  @override
  void initState() {
    super.initState();

    if (isCurrentUser) {
      tabController = TabController(length: tabList.length, vsync: this);
    }
    initializeLoadList();
    fetchUserInformation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scrollController
      ..removeListener(listener)
      ..addListener(listener);
  }

  @override
  void dispose() {
    scrollController?.dispose();
    super.dispose();
  }

  void listener() {
    double triggerHeight = expandedHeight - kToolbarHeight;
    if (isCurrentUser) {
      triggerHeight -= tabBarHeight;
    }
    titleAnimateStreamController.add(scrollController.offset >= triggerHeight);
  }

  void initializeLoadList() {
    loadingBase = LoadingBase(
      request: (int id) => PostAPI.getPostList(
        'user',
        isMore: id != 0,
        lastValue: id,
        additionAttrs: <String, dynamic>{'uid': uid},
      ),
      contentFieldName: 'topics',
    );
    listConfig = ListConfig<Map<String, dynamic>>(
      sourceList: loadingBase,
      padding: EdgeInsets.symmetric(vertical: 10.w),
      itemBuilder: (_, Map<String, dynamic> model, int index) {
        final Post post = Post.fromJson(model['topic'] as Map<String, dynamic>);
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: PostCard(post, parentContext: context, fromPage: 'user'),
        );
      },
      indicatorBuilder: (BuildContext context, IndicatorStatus status) {
        return RefreshListWrapper.indicatorBuilder(
          context,
          status,
          loadingBase,
          isSliver: false,
        );
      },
    );
  }

  Future<void> fetchUserInformation() async {
    try {
      if (uid == currentUser.uid) {
        user = currentUser;
      } else {
        final Map<String, dynamic> _user =
            (await UserAPI.getUserInfo(uid: uid)).data as Map<String, dynamic>;
        user = UserInfo.fromJson(_user);
      }

      Future.wait<void>(
        <Future<dynamic>>[_getLevel(), _getTags(), _getFollowingCount()],
        eagerError: true,
      ).then((dynamic _) {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      LogUtils.e('Failed in fetching user information: $e');
      return;
    }
  }

  Future<void> _getLevel() async {
    final Response<Map<String, dynamic>> response = await UserAPI.getLevel(uid);
    final Map<String, dynamic> data = response.data;
    userLevelScore = UserLevelScore.fromJson(
      data['score'] as Map<String, dynamic>,
    );
  }

  Future<void> _getTags() async {
    final Response<Map<String, dynamic>> response = await UserAPI.getTags(uid);
    final Map<String, dynamic> data = response.data;
    final List<dynamic> tags = data['data'] as List<dynamic>;
    final List<UserTag> _userTags = <UserTag>[];
    for (final dynamic tag in tags) {
      _userTags.add(UserTag.fromJson(tag as Map<String, dynamic>));
    }
    userTags
      ..clear()
      ..addAll(_userTags);
  }

  Future<void> _getFollowingCount() async {
    final Response<Map<String, dynamic>> response =
        await UserAPI.getFansAndFollowingsCount(uid);
    final Map<String, dynamic> data = response.data;
    user = user.copyWith(isFollowing: data['is_following'] == 1);
    userFans = data['fans'].toString().toInt();
    userIdols = data['idols'].toString().toInt();
  }

  Future<bool> onRefresh() => loadingBase.refresh();

  void avatarTap() {
    navigatorState.pushNamed(
      Routes.openjmuImageViewer,
      arguments: <String, dynamic>{
        'index': 0,
        'pics': <ImageBean>[
          ImageBean(
            id: widget.uid,
            imageUrl: '${API.userAvatar}?uid=$uid&size=f640',
          ),
        ],
        'needsClear': true,
      },
    );
  }

  void requestFollow() {
    if (user.isFollowing) {
      UserAPI.unFollow(uid);
    } else {
      UserAPI.follow(uid);
    }
    setState(() {
      user = user.copyWith(isFollowing: !user.isFollowing);
    });
  }

  Future<void> removeFromBlacklist(
    BuildContext context,
    BlacklistUser user,
  ) async {
    final bool confirm = await ConfirmationDialog.show(
      context,
      title: '移出黑名单',
      content: '确定不再屏蔽此人吗?',
      showConfirm: true,
    );
    if (confirm) {
      UserAPI.fRemoveFromBlacklist(user);
    }
  }

  Widget appbar(PullToRefreshScrollNotificationInfo info) {
    /// Remember to add offset to the effect of zooming.
    final double offset = info?.dragOffset ?? 0.0;

    /// When we are dragging down the appbar, the [RefreshIndicatorMode] would be
    /// [RefreshIndicatorMode.drag], at that time we need to display the indicator.
    final bool shouldAnimateIndicator = info?.mode == RefreshIndicatorMode.drag;

    /// Multiply a proper amount to the offset to get rotate value for the indicator.
    final double indicatorRotateOffset = offset / Screens.width * 2;

    return StreamBuilder<bool>(
      initialData: false,
      stream: titleAnimateStream,
      builder: (BuildContext _, AsyncSnapshot<bool> data) {
        final bool shouldTitleDisplay = data.data;
        return SliverAppBar(
          brightness: shouldTitleDisplay
              ? context.themeData.brightness
              : Brightness.dark,
          expandedHeight: expandedHeight + offset,
          elevation: 0.0,
          pinned: true,
          leading: BackButton(
            color: shouldTitleDisplay ? null : Colors.white,
          ),
          actions: <Widget>[
            if (info?.refreshWidget != null)
              UnconstrainedBox(
                child: RefreshProgressIndicator(
                  value: shouldAnimateIndicator ? indicatorRotateOffset : null,
                  valueColor: AlwaysStoppedAnimation<Color>(currentThemeColor),
                  strokeWidth: 2.0,
                ),
              ),
          ],
          centerTitle: true,
          title: AnimatedSwitcher(
            duration: kThemeChangeDuration,
            child: shouldTitleDisplay
                ? appBarTitleWidget
                : const SizedBox.shrink(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: appBarBackgroundWidget,
          ),
          bottom: isCurrentUser ? userTabBar : null,
        );
      },
    );
  }

  Widget get appBarTitleWidget {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UserAPI.getAvatar(size: 36.0, uid: uid),
        emptyDivider(width: 12.w),
        Text(
          user?.name ?? '',
          style: TextStyle(
            color: context.themeData.textTheme.bodyText1.color,
            fontSize: 21.sp,
          ),
        ),
      ],
    );
  }

  Widget get appBarBackgroundWidget {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          top: 0,
          left: 0.0,
          right: 0.0,
          child: Image(
            image: UserAPI.getAvatarProvider(uid: uid, size: 640),
            fit: BoxFit.cover,
          ),
        ),
        ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(color: Colors.black54),
          ),
        ),
        Positioned(
          top: Screens.topSafeHeight + kToolbarHeight,
          left: 0.0,
          right: 0.0,
          height: Screens.width / 1.25 - kToolbarHeight,
          child: userInfoWidget,
        ),
      ],
    );
  }

  PreferredSizeWidget get userTabBar {
    return PreferredSize(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18.w),
            topRight: Radius.circular(18.w),
          ),
          color: context.themeData.primaryColor,
        ),
        alignment: AlignmentDirectional.centerStart,
        child: TabBar(
          controller: tabController,
          isScrollable: true,
          indicatorWeight: 4.h,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(fontSize: 18.sp),
          labelPadding: EdgeInsets.symmetric(horizontal: 12.w),
          tabs: List<Tab>.generate(
            tabList.length,
            (int index) {
              return Tab(
                text: tabList[index],
              );
            },
          ),
        ),
      ),
      preferredSize: Size.fromHeight(tabBarHeight),
    );
  }

  Widget get userInfoWidget {
    return Container(
      padding: EdgeInsets.only(
        bottom: Screens.width * 0.04,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: <Widget>[
                userAvatar,
                const Spacer(),
                if (isCurrentUser) editProfileButton,
                if (isCurrentUser) qrCodeWidget,
                if (!isCurrentUser && user != null) followButton,
              ],
            ),
          ),
          Row(
            children: <Widget>[
              usernameWidget,
              if (Constants.developerList.contains(user?.uid ?? 0))
                SizedBox(width: 8.w),
              if (Constants.developerList.contains(user?.uid ?? 0))
                DeveloperTag(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 4.h,
                  ),
                  height: 32.h,
                ),
            ],
          ),
          signatureWidget,
          if (user != null)
            SizedBox(
              height: 40.h,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    sexualWidget(user: user),
                    levelWidget,
                    if (userTags.isNotEmpty) ...tagsWidget,
                  ],
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          fansAndIdolsWidget,
        ],
      ),
    );
  }

  Widget get userAvatar {
    return GestureDetector(
      onTap: avatarTap,
      child: Container(
        width: Screens.width / 5,
        height: Screens.width / 5,
        padding: EdgeInsets.all(Screens.width * 0.01),
        child: ClipOval(
          child: Image(
            image: UserAPI.getAvatarProvider(uid: uid),
            frameBuilder: (
              BuildContext _,
              Widget child,
              int frame,
              bool wasSynchronouslyLoaded,
            ) {
              if (wasSynchronouslyLoaded) {
                return child;
              }
              return AnimatedOpacity(
                child: child,
                opacity: frame == null ? 0 : 1,
                duration: 1.seconds,
                curve: Curves.easeOut,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget get followButton {
    return MaterialButton(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minWidth: 0.0,
      height: 46.h,
      padding: EdgeInsets.symmetric(
        horizontal: 14.w,
      ),
      color: Colors.black26,
      elevation: 0.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.w),
      ),
      onPressed: requestFollow,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!(user?.isFollowing ?? false))
            SvgPicture.asset(
              R.ASSETS_ICONS_USER_FOLLOW_SVG,
              width: 30.w,
              height: 30.w,
              fit: BoxFit.fill,
            ),
          Text(
            '${(user?.isFollowing ?? false) ? '已' : ''}关注',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget get editProfileButton {
    return Padding(
      padding: EdgeInsets.only(right: 10.w),
      child: MaterialButton(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minWidth: 0.0,
        height: 46.h,
        padding: EdgeInsets.symmetric(
          horizontal: 14.w,
        ),
        color: Colors.black26,
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.w),
        ),
        onPressed: () {
          navigatorState.pushNamed(Routes.openjmuEditProfilePage);
        },
        child: Text(
          '编辑资料',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  Widget get qrCodeWidget {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: SizedBox.fromSize(
        size: Size.square(46.h),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.black26,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SvgPicture.asset(
              R.ASSETS_ICONS_USER_QR_CODE_SVG,
              width: 34.w,
              height: 34.w,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
      onTap: () {
        navigatorState.pushNamed(Routes.openjmuUserQrCode);
      },
    );
  }

  Widget get usernameWidget {
    return Padding(
      padding: EdgeInsets.only(left: 20.w),
      child: Text(
        user?.name ?? '',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.fade,
      ),
    );
  }

  Widget get signatureWidget {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Text(
        () {
          if (user == null) {
            return '';
          } else {
            return user.signature ?? '这个人很懒，什么都没写';
          }
        }(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 18.sp,
          fontWeight: FontWeight.w300,
        ),
        textAlign: TextAlign.start,
        maxLines: 1,
        overflow: TextOverflow.fade,
      ),
    );
  }

  Widget get levelWidget {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 8.w,
            vertical: 4.h,
          ),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(20.w),
          ),
          child: Text(
            ' Lv.${userLevelScore?.levelInfo?.level ?? 0}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> get tagsWidget {
    return List<Widget>.generate(
      userTags.length,
      (int index) {
        return Container(
          margin: EdgeInsets.only(right: 12.w),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.w),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 1.h,
              ),
              color: const Color(0x44ffffff),
              child: Text(
                userTags[index].name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget get fansAndIdolsWidget {
    final TextStyle titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 15.sp,
    );
    final TextStyle countStyle = TextStyle(
      color: Colors.white,
      fontSize: 28.sp,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              navigatorState.pushNamed(
                Routes.openjmuUserListPage,
                arguments: <String, dynamic>{
                  'user': user,
                  'type': 1,
                },
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('关注', style: titleStyle),
                SizedBox(width: 8.w),
                Text('${userIdols ?? ''}', style: countStyle),
              ],
            ),
          ),
          SizedBox(width: 20.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              navigatorState.pushNamed(
                Routes.openjmuUserListPage,
                arguments: <String, dynamic>{
                  'user': user,
                  'type': 2,
                },
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('粉丝', style: titleStyle),
                SizedBox(width: 8.w),
                Text('${userFans ?? ''}', style: countStyle),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget get banListWidget {
    if (UserAPI.blacklist.isNotEmpty) {
      return GridView.count(
        crossAxisCount: 3,
        children: List<Widget>.generate(
          UserAPI.blacklist.length,
          (int i) => blacklistUser(UserAPI.blacklist.elementAt(i)),
        ),
      );
    } else {
      return Center(
        child: Text(
          '黑名单为空',
          style: TextStyle(fontSize: 20.sp),
        ),
      );
    }
  }

  Widget blacklistUser(BlacklistUser user) {
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          UserAvatar(uid: user.uid, size: 64.0, canJump: false),
          Text(
            user.username,
            style: TextStyle(fontSize: 18.sp),
            overflow: TextOverflow.ellipsis,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => removeFromBlacklist(context, user),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10.w,
                vertical: 6.h,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.w),
                color: currentThemeColor.withAlpha(0x88),
              ),
              child: Text(
                '移出黑名单',
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body = LoadingMoreList<Map<String, dynamic>>(listConfig);
    if (isCurrentUser) {
      body = TabBarView(
        controller: tabController,
        children: <Widget>[
          body,
          if (isCurrentUser) banListWidget,
        ],
      );
    }
    return Material(
      child: PullToRefreshNotification(
        color: Colors.blue,
        pullBackOnRefresh: true,
        onRefresh: onRefresh,
        child: NestedScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableClampingScrollPhysics(),
          headerSliverBuilder: (BuildContext _, bool __) {
            return <Widget>[PullToRefreshContainer(appbar)];
          },
          body: body,
        ),
      ),
    );
  }
}
