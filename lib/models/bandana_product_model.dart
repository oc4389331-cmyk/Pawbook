import 'package:flutter/material.dart';

class BandanaProductModel {
  final String id;
  final String name;
  final double priceUsd;
  final int pricePoints;
  final String imageUrl;
  final int stock;
  final String tag;
  final int colorValue;
  final String description;

  const BandanaProductModel({
    required this.id,
    required this.name,
    required this.priceUsd,
    required this.pricePoints,
    required this.imageUrl,
    this.stock = 2,
    this.tag = 'Exclusivo',
    this.colorValue = 0xFF9945FF,
    this.description = '',
  });

  bool get isSoldOut => stock <= 0;

  Color get color => Color(colorValue);

  BandanaProductModel copyWith({
    String? id,
    String? name,
    double? priceUsd,
    int? pricePoints,
    String? imageUrl,
    int? stock,
    String? tag,
    int? colorValue,
    String? description,
  }) {
    return BandanaProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      priceUsd: priceUsd ?? this.priceUsd,
      pricePoints: pricePoints ?? this.pricePoints,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      tag: tag ?? this.tag,
      colorValue: colorValue ?? this.colorValue,
      description: description ?? this.description,
    );
  }

  factory BandanaProductModel.fromJson(Map<String, dynamic> json) {
    return BandanaProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      priceUsd: (json['price_usd'] is num)
          ? (json['price_usd'] as num).toDouble()
          : (json['priceUsd'] is num ? (json['priceUsd'] as num).toDouble() : 0.0),
      pricePoints: (json['price_points'] is num)
          ? (json['price_points'] as num).toInt()
          : (json['pricePoints'] is num ? (json['pricePoints'] as num).toInt() : 0),
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      stock: (json['stock'] is num) ? (json['stock'] as num).toInt() : 2,
      tag: json['tag'] ?? 'Exclusivo',
      colorValue: (json['color_value'] is int)
          ? json['color_value']
          : (json['colorValue'] is int ? json['colorValue'] : 0xFF9945FF),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price_usd': priceUsd,
      'price_points': pricePoints,
      'image_url': imageUrl,
      'stock': stock,
      'tag': tag,
      'color_value': colorValue,
      'description': description,
    };
  }
}
