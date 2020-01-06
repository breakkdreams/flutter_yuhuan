import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:flutter_yuhuan/service/data_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info/package_info.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';


class WebPage extends StatefulWidget {

  @override
  State<StatefulWidget> createState() {
    return Widget_WebView_State();
  }
}

class Widget_WebView_State extends State<WebPage> with SingleTickerProviderStateMixin {
  static const platform = const MethodChannel('app.channel.shared.data');

  FlutterWebviewPlugin flutterWebviewPlugin = FlutterWebviewPlugin();

  ///检查是否有权限
  checkPermission() async {
    //检查是否已有读写内存权限
    PermissionStatus status = await PermissionHandler().checkPermissionStatus(PermissionGroup.storage);

    //判断如果还没拥有读写权限就申请获取权限
    if(status != PermissionStatus.granted){
      var map = await PermissionHandler().requestPermissions([PermissionGroup.storage]);
      if(map[PermissionGroup.storage] != PermissionStatus.granted){
        return false;
      }
    }
    _checkForUpdates();
  }

  String url = 'http://js3.300c.cn/image_search/imageidentify/#/Home';


  Future<void> _checkForUpdates() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;
    String updateUrl = Theme.of(context).platform == TargetPlatform.iOS
        ? ''
        : 'http://js3.300c.cn/image_search/yuhuan.apk';
    try {
      String versionShort = '';
      //获取服务器版本
      await request('get_version', formData: {}).then((val) {
        var data = json.decode(val.toString());
        if (data['code'] == 200) {
          if(data['data']!=null){
            versionShort = data['data']['version'];
          }
        }
      });

      if (versionShort.isNotEmpty && version.hashCode != versionShort.hashCode) {
        final bool wantsUpdate = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) =>
              _buildDialog(context, updateUrl, packageInfo, versionShort),
          barrierDismissible: false,
        );
        if (wantsUpdate != null && wantsUpdate) {
          launch(updateUrl,
            forceSafariVC: false,
          );
        }
      }
    } catch (e) {}
  }

  Widget _buildDialog(
      BuildContext context, String updateUrl, PackageInfo packageInfo, String versionShort) {
    final ThemeData theme = Theme.of(context);
    final TextStyle dialogTextStyle =
    theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
    flutterWebviewPlugin.hide();
    return CupertinoAlertDialog(
      title: Text('是否立即更新?'),
      content: Text('检测到新版本 v$versionShort', style: dialogTextStyle),
      actions: <Widget>[
        CupertinoDialogAction(
          child: const Text('下次再说'),
          onPressed: () {
            Navigator.pop(context, false);
            flutterWebviewPlugin.show();
          },
        ),
        CupertinoDialogAction(
          child: const Text('立即更新'),
          onPressed: () {
            Navigator.pop(context, true);
            flutterWebviewPlugin.show();
          },
        ),
      ],
    );
  }

  _save(path) {
    String suffix = path.substring(path.lastIndexOf(".") + 1);
    if(suffix == 'jpg' || suffix == 'jpeg' || suffix == 'png'){
      _saveImg(path);
    }
    Fluttertoast.showToast(
      msg: "保存成功",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIos: 1,
    );
  }

  _saveImg(imgpath) async{
    var response = await Dio().get(imgpath, options: Options(responseType: ResponseType.bytes));
    final result = await ImageGallerySaver.saveImage(Uint8List.fromList(response.data));
  }


  @override
  void initState() {
    super.initState();
    checkPermission();
    flutterWebviewPlugin.onUrlChanged.listen((String url) {
      if(url.contains('/Blank?')){
        var strs=url.split("url=");
        String encodedUrl = strs[1];
        encodedUrl = Uri.decodeComponent(encodedUrl);
        _save(encodedUrl);
      }else if(!url.startsWith('http')){
        launch(url);
        flutterWebviewPlugin.goBack();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body:WebviewScaffold(
          url: url,
          appBar: PreferredSize(
            preferredSize:
            Size.fromHeight(MediaQuery.of(context).size.height * 0.07),
            child: SafeArea(
              top: true,
              child: Offstage(),
            ),
          ),
        )
    );
  }


  @override
  void dispose() {
    flutterWebviewPlugin.dispose();
    super.dispose();
  }

}
