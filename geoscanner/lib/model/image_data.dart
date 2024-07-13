import 'dart:typed_data';

class ImageData {
  final Uint8List data;
  final String timestamp;
  final String recordId; // 添加 recordId 属性

  ImageData(this.data, this.timestamp, this.recordId);

  Uint8List toBytes() {
    final recordIdBytes = Uint8List.fromList(recordId.codeUnits);
    final timestampBytes = Uint8List.fromList(timestamp.codeUnits);
    final delimiter = Uint8List(1)..[0] = 0; // Use 0 as delimiter
    return Uint8List.fromList(recordIdBytes + delimiter + timestampBytes + delimiter + data);
  }
}
