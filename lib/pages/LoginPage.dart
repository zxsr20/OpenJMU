import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:ff_annotation_route/ff_annotation_route.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:OpenJMU/constants/Constants.dart';
import 'package:OpenJMU/widgets/CommonWebPage.dart';
import 'package:OpenJMU/widgets/RoundedCheckBox.dart';
import 'package:OpenJMU/widgets/announcement/AnnouncementWidget.dart';

@FFRoute(
  name: "openjmu://login",
  routeName: "登录页",
  argumentNames: ["initAction"],
  pageRouteType: PageRouteType.material,
)
class LoginPage extends StatefulWidget {
  final String initAction;

  const LoginPage({
    Key key,
    this.initAction,
  }) : super(key: key);

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _formScrollController = ScrollController();
  final TextEditingController _usernameController = TextEditingController(
    text: DataUtils.recoverWorkId(),
  );
  final TextEditingController _passwordController = TextEditingController();
  final List<Color> colorGradient = const <Color>[
    Color(0xffff8976),
    Color(0xffff3c33)
  ];

  String _username = DataUtils.recoverWorkId() ?? "", _password = "";

  bool _agreement = false;
  bool _login = false;
  bool _loginDisabled = true;
  bool _isObscure = true;
  bool _usernameCanClear = false;
  bool _keyboardAppeared = false;

  bool get loginButtonEnable => !(_login || _loginDisabled);

  Color currentColor = ThemeUtils.currentThemeColor;
  Color _defaultIconColor = Colors.grey;

  @override
  void initState() {
    Instances.eventBus.on<ChangeThemeEvent>().listen((event) {
      currentColor = event.color;
      if (mounted) setState(() {});
    });
    _usernameController
      ..addListener(() {
        _username = _usernameController.text;
        if (this.mounted) {
          if (_usernameController.text.length > 0 && !_usernameCanClear) {
            setState(() {
              _usernameCanClear = true;
            });
          } else if (_usernameController.text.length == 0 &&
              _usernameCanClear) {
            setState(() {
              _usernameCanClear = false;
            });
          }
        }
      });
    _passwordController
      ..addListener(() {
        _password = _passwordController.text;
      });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _usernameController?.dispose();
    _passwordController?.dispose();
    super.dispose();
  }

  int last = 0;
  Future<bool> doubleBackExit() {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - last > 800) {
      showShortToast("再按一次退出应用");
      last = DateTime.now().millisecondsSinceEpoch;
      return Future.value(false);
    } else {
      cancelToast();
      return Future.value(true);
    }
  }

  Widget get topBackground => Positioned(
        right: 0.0,
        top: 0.0,
        child: Image.asset(
          "images/login_top.png",
          width: MediaQuery.of(context).size.width - suSetSp(60.0),
          fit: BoxFit.fitWidth,
        ),
      );

  Widget get bottomBackground => Positioned(
        left: 0.0,
        right: 0.0,
        bottom: 15.0,
        child: Center(
          child: Image.asset(
            "images/login_bottom.png",
            color: Colors.grey.withAlpha(50),
            width: MediaQuery.of(context).size.width - 150.0,
            fit: BoxFit.fitWidth,
          ),
        ),
      );

  Widget get logo => Positioned(
        right: suSetSp(40.0),
        top: suSetSp(50.0),
        child: Hero(
          tag: "Logo",
          child: SvgPicture.asset(
            "images/splash_page_logo.svg",
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            width: suSetSp(120.0),
            height: suSetSp(120.0),
          ),
        ),
      );

  Widget get logoTitle => Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        textBaseline: TextBaseline.ideographic,
        children: <Widget>[
          Stack(
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(
                  top: suSetSp(10.0),
                  left: suSetSp(6.0),
                  right: suSetSp(6.0),
                ),
                child: Text(
                  "OPENJMU",
                  style: TextStyle(
                    color: Theme.of(context).iconTheme.color,
                    fontSize: suSetSp(50.0),
                    fontFamily: "chocolate",
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  Widget get usernameTextField => TextFormField(
        controller: _usernameController,
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.person,
            color: Theme.of(context).iconTheme.color,
            size: suSetSp(24.0),
          ),
          suffixIcon: _usernameCanClear
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Theme.of(context).iconTheme.color,
                    size: suSetSp(24.0),
                  ),
                  onPressed: _usernameController.clear,
                )
              : null,
          border: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: ThemeUtils.defaultColor,
            ),
          ),
          contentPadding: EdgeInsets.all(suSetSp(12.0)),
          labelText: '工号/学号',
          labelStyle: TextStyle(
            color: Theme.of(context).textTheme.title.color,
            fontSize: suSetSp(18.0),
          ),
        ),
        style: TextStyle(
          color: Theme.of(context).textTheme.title.color,
        ),
        strutStyle: StrutStyle(
          fontSize: suSetSp(18.0),
          height: suSetSp(1.7),
          forceStrutHeight: true,
        ),
        cursorColor: ThemeUtils.defaultColor,
        onSaved: (String value) => _username = value,
        validator: (String value) {
          if (value.isEmpty) return '请输入账户';
          return null;
        },
        keyboardType: TextInputType.number,
        enabled: !_login,
      );

  Widget get passwordTextField => TextFormField(
        controller: _passwordController,
        onSaved: (String value) => _password = value,
        obscureText: _isObscure,
        validator: (String value) {
          if (value.isEmpty) return '请输入密码';
          return null;
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: ThemeUtils.defaultColor,
            ),
          ),
          contentPadding: EdgeInsets.all(suSetSp(12.0)),
          prefixIcon: Icon(
            Icons.lock,
            color: Theme.of(context).iconTheme.color,
            size: suSetSp(24.0),
          ),
          labelText: '密码',
          labelStyle: TextStyle(
            color: Theme.of(context).textTheme.title.color,
            fontSize: suSetSp(18.0),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _isObscure ? Icons.visibility : Icons.visibility_off,
              color: _defaultIconColor,
              size: suSetSp(24.0),
            ),
            onPressed: () {
              setState(() {
                _isObscure = !_isObscure;
                _defaultIconColor =
                    _isObscure ? Colors.grey : ThemeUtils.defaultColor;
              });
            },
          ),
        ),
        style: TextStyle(
          color: Theme.of(context).textTheme.title.color,
        ),
        strutStyle: StrutStyle(
          fontSize: suSetSp(18.0),
          height: suSetSp(1.7),
          forceStrutHeight: true,
        ),
        cursorColor: ThemeUtils.defaultColor,
        enabled: !_login,
      );

  Widget get noAccountButton => Padding(
        padding: EdgeInsets.zero,
        child: Align(
          alignment: Alignment.center,
          child: FlatButton(
            padding: EdgeInsets.all(0.0),
            child: Text(
              '没有账号',
              style: TextStyle(
                color: Colors.grey,
                fontSize: suSetSp(16.0),
              ),
            ),
            onPressed: () {},
          ),
        ),
      );

  Widget get findWorkId => Padding(
        padding: EdgeInsets.zero,
        child: Align(
          alignment: Alignment.center,
          child: FlatButton(
            padding: EdgeInsets.all(0.0),
            child: Text(
              '学工号查询',
              style: TextStyle(
                color: Colors.grey,
                fontSize: suSetSp(16.0),
              ),
            ),
            onPressed: () {
              CommonWebPage.jump(
                "http://myid.jmu.edu.cn/ids/EmployeeNoQuery.aspx",
                "集大通行证 - 工号查询",
              );
            },
          ),
        ),
      );

  Widget get forgetPasswordButton => Padding(
        padding: EdgeInsets.zero,
        child: Align(
          alignment: Alignment.center,
          child: FlatButton(
            padding: EdgeInsets.all(0.0),
            child: Text(
              '忘记密码',
              style: TextStyle(
                color: Colors.grey,
                fontSize: suSetSp(16.0),
              ),
            ),
            onPressed: resetPassword,
          ),
        ),
      );

  Widget get userAgreementCheckbox => Expanded(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox.fromSize(
              size: Size.square(suSetWidth(42.0)),
              child: RoundedCheckbox(
                value: _agreement,
                inactiveColor: Theme.of(context).iconTheme.color,
                onChanged: !_login
                    ? (value) {
                        setState(() {
                          _agreement = value;
                        });
                        validateForm();
                      }
                    : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                      text: "登录即代表您同意",
                    ),
                    TextSpan(
                      text: "《用户协议》",
                      style: TextStyle(
                        color: ThemeUtils.defaultColor,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => CommonWebPage.jump(
                              "${API.homePage}/license.html",
                              "OpenJMU 用户协议",
                            ),
                    ),
                  ],
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: suSetSp(15.0),
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      );

  Widget get loginButton => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: loginButtonEnable
            ? () {
                loginButtonPressed(context);
              }
            : null,
        child: Container(
          margin: EdgeInsets.only(left: suSetWidth(4.0)),
          width: suSetSp(100.0),
          height: suSetSp(50.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(suSetSp(6.0)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                blurRadius: suSetSp(10.0),
                color: !_loginDisabled
                    ? colorGradient[1].withAlpha(100)
                    : Colors.grey[400],
                offset: Offset(0.0, suSetSp(10.0)),
              ),
            ],
            gradient: !_loginDisabled
                ? LinearGradient(colors: colorGradient)
                : LinearGradient(colors: [Colors.grey, Colors.grey]),
          ),
          child: Center(
            child: !_login
                ? Icon(
                    Icons.arrow_forward,
                    size: suSetWidth(36.0),
                    color: Colors.white,
                  )
                : SizedBox.fromSize(
                    size: Size.square(suSetWidth(32.0)),
                    child: Constants.progressIndicator(
                      strokeWidth: 3.0,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      );

  Widget get loginForm => SafeArea(
        child: Form(
          key: _formKey,
          child: Align(
            alignment:
                _keyboardAppeared ? Alignment.bottomCenter : Alignment.center,
            child: ListView(
              shrinkWrap: true,
              controller: _formScrollController,
              padding: EdgeInsets.symmetric(horizontal: suSetSp(50.0)),
              physics:
                  NeverScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              children: <Widget>[
                logoTitle,
                Constants.emptyDivider(height: suSetSp(40.0)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: suSetSp(10.0),
                    vertical: suSetSp(10.0),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(suSetSp(6.0)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        blurRadius: 20.0,
                        color: Theme.of(context).dividerColor,
                      ),
                    ],
                    color: Theme.of(context).cardColor,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (Configs.announcementsEnabled)
                        AnnouncementWidget(
                          context,
                          radius: 6.0,
                        ),
                      usernameTextField,
                      Constants.emptyDivider(height: suSetSp(10.0)),
                      passwordTextField,
                      Constants.emptyDivider(height: suSetSp(10.0)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          findWorkId,
                          forgetPasswordButton,
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: suSetSp(20.0)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      userAgreementCheckbox,
                      loginButton,
                    ],
                  ),
                ),
                Constants.emptyDivider(height: suSetSp(30.0)),
              ],
            ),
          ),
          onChanged: validateForm,
        ),
      );

  void loginButtonPressed(context) {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      setState(() {
        _login = true;
      });
      DataUtils.login(_username, _password).then((result) {
        if (result) {
          navigatorState.pushNamedAndRemoveUntil(
            "openjmu://home",
            (_) => false,
            arguments: {"initAction": widget.initAction},
          );
        } else {
          _login = false;
          if (mounted) setState(() {});
        }
      }).catchError((e) {
        _login = false;
        if (mounted) setState(() {});
      });
    }
  }

  void resetPassword() async {
    return showPlatformDialog<Null>(
      context: context,
      builder: (BuildContext dialogContext) {
        return PlatformAlertDialog(
          title: Text('忘记密码'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('找回密码详见'),
                Text('网络中心主页 -> 集大通行证'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('返回'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            FlatButton(
              child: Text('查看'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                return CommonWebPage.jump(
                  "https://net.jmu.edu.cn/info/1309/2476.htm",
                  "集大通行证登录说明",
                  withCookie: false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  void validateForm() {
    if (_username != "" && _password != "" && _agreement && _loginDisabled) {
      setState(() {
        _loginDisabled = false;
      });
    } else if (_username == "" || _password == "" || !_agreement) {
      setState(() {
        _loginDisabled = true;
      });
    }
  }

  void setAlignment(context) {
    final double inputMethodHeight = MediaQuery.of(context).viewInsets.bottom;
    if (inputMethodHeight > 1.0 && !_keyboardAppeared) {
      setState(() {
        _keyboardAppeared = true;
      });
    } else if (inputMethodHeight <= 1.0 && _keyboardAppeared) {
      setState(() {
        _keyboardAppeared = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    setAlignment(context);
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.dark,
      child: WillPopScope(
        onWillPop: doubleBackExit,
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: Stack(
            children: <Widget>[
              topBackground,
              bottomBackground,
              logo,
              loginForm,
            ],
          ),
          resizeToAvoidBottomInset: true,
        ),
      ),
    );
  }
}
