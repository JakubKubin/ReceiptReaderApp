// models/picture.dart

library;

import 'dart:convert';

class Picture {
  int id;
  String body;
  String title;

  Picture({required this.id, required this.body, required this.title});

  Picture copyWith({
    required int id,
    required String body,
    required String title,
  }) {
    return Picture(id: id, body: body, title: title);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'body': body,
      'title': title,
    };
  }

  factory Picture.fromMap(Map<String, dynamic> map) {
    return Picture(
      id: map['id'] as int,
      body: map['body'] as String,
      title: map['title'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Picture.fromJson(String source) =>
      Picture.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'Picture(id: $id, body: $body, title: $title)';

  @override
  bool operator ==(covariant Picture other) {
    if (identical(this, other)) return true;

    return other.id == id && other.body == body && other.title == title;
  }

  @override
  int get hashCode => id.hashCode ^ body.hashCode ^ title.hashCode;
}
