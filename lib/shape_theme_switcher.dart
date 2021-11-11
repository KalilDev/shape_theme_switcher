import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

class ShapeThemeSwitcher extends StatefulWidget {
  final ThemeData theme;
  final Widget child;
  final Alignment alignment;
  final ShapeBorderTween borderTween;
  final Duration duration;
  ShapeThemeSwitcher({
    Key? key,
    required this.theme,
    required this.child,
    ShapeBorderTween? borderTween,
    ShapeBorder? border = const CircleBorder(),
    this.alignment = Alignment.bottomRight,
    this.duration = const Duration(milliseconds: 200),
  })  : borderTween =
            borderTween ?? ShapeBorderTween(begin: border!, end: border),
        super(key: key);

  @override
  _ShapeThemeSwitcherState createState() => _ShapeThemeSwitcherState();
}

class _ShapeThemeSwitcherState extends State<ShapeThemeSwitcher>
    with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey();
  late ThemeData theme;
  ui.Image? oldThemedImage;
  late final _controller = AnimationController(
    vsync: this,
  )..addStatusListener(_onAnimationStatus);
  late final _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    setState(() => oldThemedImage = null);
    _controller.value = 0;
  }

  void initState() {
    super.initState();
    theme = widget.theme;
  }

  void _triggerThemeChange() {
    final renderBoundary = _boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    renderBoundary.toImage().then(_onImageReady);
  }

  void _onImageReady(ui.Image image) {
    setState(() {
      oldThemedImage = image;
      theme = widget.theme;
    });
    _controller.duration = widget.duration;
    _controller.forward(from: 0);
  }

  void didUpdateWidget(ShapeThemeSwitcher old) {
    if (old.theme != widget.theme) {
      WidgetsBinding.instance!
          .addPostFrameCallback((_) => _triggerThemeChange());
    }
    super.didUpdateWidget(old);
  }

  Widget _body(BuildContext context) {
    var bodyWithTargetTheme = Theme(
      data: theme,
      child: widget.child,
    );
    if (oldThemedImage == null) {
      return bodyWithTargetTheme;
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Stack(
        children: [
          Positioned.fill(child: bodyWithTargetTheme),
          Positioned.fill(
              child: ClipPath(
            clipper: PositionedShapeClipper(
              widget.alignment,
              _animation.value,
              widget.borderTween.transform(_animation.value)!,
            ),
            child: child,
          ))
        ],
      ),
      child: IgnorePointer(
        child: RawImage(
          image: oldThemedImage,
          scale: 1.0,
          fit: BoxFit.fill,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: _body(context),
    );
  }
}

class PositionedShapeClipper extends CustomClipper<Path> {
  final Alignment origin;
  final double t;
  final ShapeBorder shape;

  PositionedShapeClipper(
    this.origin,
    this.t,
    this.shape,
  );

  @override
  Path getClip(Size size) {
    final originPoint = origin.alongSize(size);
    final radius = [
          size.topLeft(Offset.zero),
          size.topRight(Offset.zero),
          size.bottomLeft(Offset.zero),
          size.bottomRight(Offset.zero),
        ].fold<double>(
          0,
          (currRadius, p) => math.max(
            currRadius,
            (originPoint - p).distance,
          ),
        ) *
        1.2;
    final rectPath = Path()..addRect(Offset.zero & size);
    final shapeRect = Rect.fromCircle(center: originPoint, radius: radius * t);
    final shapePath = shape.getOuterPath(shapeRect);
    return Path.combine(PathOperation.difference, rectPath, shapePath);
  }

  @override
  bool shouldReclip(PositionedShapeClipper oldClipper) =>
      t != oldClipper.t || origin != oldClipper.origin;
}
