import 'package:flutter/material.dart';

import '../../data/person.dart';
import '../format/person_text.dart';

/// A person's WikiTree thumbnail, or a coloured monogram when there is none.
///
/// WikiTree's app policies only allow the 75-pixel thumbnail to be displayed,
/// so that is what [Person.photoUrl] points at. Most profiles have no photo at
/// all, which makes the monogram the common case rather than a fallback.
class PhotoAvatar extends StatelessWidget {
  const PhotoAvatar({super.key, required this.person, this.size = 56});

  final Person person;
  final double size;

  static const List<Color> _palette = <Color>[
    Color(0xFF4C6B2F),
    Color(0xFF2F5A6B),
    Color(0xFF6B4C2F),
    Color(0xFF5A2F6B),
    Color(0xFF2F6B57),
    Color(0xFF6B2F3F),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.22);
    final photoUrl = person.photoUrl;
    final monogram = _Monogram(person: person, size: size);

    final image = photoUrl == null
        ? monogram
        : Image.network(
            photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => monogram,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : monogram,
          );

    return Semantics(
      image: photoUrl != null,
      label: PersonText.of(context).photoLabel(person),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(width: size, height: size, child: image),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.person, required this.size});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        PhotoAvatar._palette[person.id.abs() % PhotoAvatar._palette.length];
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        person.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
