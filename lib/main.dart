import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

void main() => runApp(MyApp());

const key = 'my32lengthsupersecretnooneknows1';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColorBrightness: Brightness.light,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final _subject = BehaviorSubject<File>();
  final encrypter = Encrypter(Salsa20(key, '12345678'));

  Stream<File> get _image => _subject.stream;

  Function(File) get _update => _subject.add;

  @override
  Widget build(BuildContext context) {
    return _documentList(context);
  }

  Widget _addDocument(BuildContext context) {
    return Scaffold(
        appBar: _appBar(),
        floatingActionButton: _addDocumentButton(context),
        body: Column(children: <Widget>[
          Flexible(fit: FlexFit.loose, flex: 2, child: _imageDisplay(context)),
          Flexible(fit: FlexFit.loose, child: _imageSelector(context)),
          Flexible(fit: FlexFit.loose, child: _action(context))
        ]));
  }

  AppBar _appBar() {
    return AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: true,
      );
  }

  FloatingActionButton _addDocumentButton(BuildContext context) {
    return FloatingActionButton(
          child: Icon(Icons.add),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => _addDocument(context))));
  }

  Widget _imageDisplay(BuildContext context) {
    return Container(
        color: new Color(0xffe9e9e9),
        child: Center(
            child: StreamBuilder(
          stream: _image,
          builder: (context, i) => i.hasData ? Image.file(i.data) : Container(),
        )));
  }

  Widget _imageSelector(BuildContext context) {
    return new Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          padding: EdgeInsets.all(10.0),
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            onPressed: selectGalleryImage,
            heroTag: "gallery0",
            tooltip: 'Pick Image from gallery',
            child: Icon(Icons.photo_library))),
    ]);
  }

  selectGalleryImage() {
    selectImage(ImageSource.gallery);
  }

  Future<void> selectImage(ImageSource source) async {
    final image = await ImagePicker.pickImage(source: source, maxWidth: 500.0);
    if (image != null) {
      _update(image);
    }
  }

  Widget _action(BuildContext context) {
    return RaisedButton(
        child: Text(
          'ENCRYPT',
          style: TextStyle(fontSize: 15.0),
        ),
        onPressed: () async {
          final image = await _image.first;
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          final encryptedImage = encrypter.encrypt(base64Image);
          final file = await _localFile;
          file.writeAsString(encryptedImage);
          Navigator.of(context).pop();
        });
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/${Random().nextInt(100500)}.encrypted');
  }

  Widget _documentList(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      floatingActionButton: _addDocumentButton(context),
      body: _docs(context),
    );
  }

  _docs(BuildContext context) {
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, dir) {
        if (dir.hasData) {
          return FutureBuilder<List<FileSystemEntity>>(
            future: dir.data.list().toList(),
            builder: (context, files) {
              if (files.hasData) {
                return ListView(
                  children: files.data.map((e) => InkWell(
                    child: Text(e.path.substring(112)),
                    onTap: () async {
                      final encrypted = await File(e.path).readAsString();
                      final imageBase64 = encrypter.decrypt(encrypted);
                      Uint8List decodedImage = base64Decode(imageBase64);
                      openDocumentDialog(decodedImage, context);
                    },
                  )).toList(),
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }

      },
    );
  }

  void openDocumentDialog(Uint8List image, context) {
    showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            children: [
              Image.memory(image),
              RaisedButton(
                child: Text('ok'),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          );
        });
  }


}
