import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geoscanner/style/custom_text_style.dart';

class UserImagePicker extends StatefulWidget {
  const UserImagePicker({
    super.key,
    required this.onPickImage,
  });

  final void Function(File pickedImage) onPickImage;

  @override
  State<UserImagePicker> createState() => _UserImagePickerState();
}

class _UserImagePickerState extends State<UserImagePicker> {
  File? _pickedImageFile;

  final ImagePicker _picker = ImagePicker();

  // Method for picking an image from camera
  void _pickImageFromCamera() async {
    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 150,
    );

    if (pickedImage == null) {
      return;
    }

    setState(() {
      _pickedImageFile = File(pickedImage.path);
    });

    widget.onPickImage(_pickedImageFile!);
  }

  // Method for picking an image from gallery
  void _pickImageFromGallery() async {
    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 150,
    );
    if (pickedImage == null) {
      return;
    }
    setState(() {
      _pickedImageFile = File(pickedImage.path);
    });

    widget.onPickImage(_pickedImageFile!);
  }

  // For users to choose the source of the image
  void _showPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              //相册
              ListTile(
                leading: const Icon(Icons.photo_album,size: 20,color: Color.fromARGB(255, 78, 78, 78),),
                title: Text("Choose from Album",style:CustomTextStyle.smallBoldBlackText,),
                onTap: () {
                  _pickImageFromGallery();
                  Navigator.of(context).pop();
                },
              ),
              //相机
              ListTile(
                leading: const Icon(Icons.camera_alt,size: 20,color: Color.fromARGB(255, 78, 78, 78),),
                title: Text("Take from Camera",style:CustomTextStyle.smallBoldBlackText,),
                onTap: () {
                  _pickImageFromCamera();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: const Color.fromARGB(255, 185, 185, 185),
          foregroundImage:
              _pickedImageFile != null ? FileImage(_pickedImageFile!) : null,
        ),
        TextButton.icon(
          onPressed: _showPicker,
          icon: const Icon(Icons.image,size: 15,color: Color.fromARGB(255, 100, 100, 100),),
          label: Text('Add Image',style:CustomTextStyle.mediumBoldGreyText,),
        ),
      ],
    );
  }
}
