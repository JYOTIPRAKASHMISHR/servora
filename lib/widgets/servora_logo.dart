import 'package:flutter/material.dart';


class ServoraLogo extends StatelessWidget {

  final double size;

  const ServoraLogo({
    super.key,
    this.size = 150,
  });


  @override
  Widget build(BuildContext context) {

    return CustomPaint(

      size: Size(size, size),

      painter: ServoraLogoPainter(),

    );

  }

}



class ServoraLogoPainter extends CustomPainter {


@override
void paint(Canvas canvas, Size size) {


final w = size.width;
final h = size.height;



// Glow

Paint glow = Paint()
  ..color = const Color(0xff0066FF).withOpacity(0.5)
  ..maskFilter = const MaskFilter.blur(
    BlurStyle.normal,
    25,
  );



canvas.drawOval(
  Rect.fromCenter(
    center: Offset(w/2,h/2),
    width:w*0.8,
    height:h*0.8,
  ),
  glow,
);




// Main S Gradient


Paint sPaint = Paint()

..shader = const LinearGradient(

colors:[

Color(0xff4FC3FF),

Color(0xff2563EB),

],

begin: Alignment.topLeft,

end: Alignment.bottomRight,

)

.createShader(
Rect.fromLTWH(0,0,w,h)
);




// S Shape


Path s = Path();



// Top curve

s.moveTo(w*0.72,h*0.20);


s.cubicTo(

w*0.55,h*0.05,

w*0.20,h*0.12,

w*0.20,h*0.35

);



s.cubicTo(

w*0.20,h*0.52,

w*0.45,h*0.55,

w*0.60,h*0.62

);



// Bottom curve

s.cubicTo(

w*0.78,h*0.72,

w*0.65,h*0.90,

w*0.40,h*0.88

);



s.cubicTo(

w*0.25,h*0.86,

w*0.15,h*0.78,

w*0.12,h*0.70

);



s.lineTo(

w*0.30,

h*0.65

);



s.cubicTo(

w*0.40,h*0.75,

w*0.60,h*0.75,

w*0.62,h*0.62

);



s.cubicTo(

w*0.63,h*0.52,

w*0.40,h*0.48,

w*0.32,h*0.40

);



s.cubicTo(

w*0.18,h*0.25,

w*0.35,h*0.12,

w*0.55,h*0.15

);



s.close();




canvas.drawPath(s,sPaint);




// Dark 3D Fold


Paint dark = Paint()

..color = const Color(0xff123B8A);



Path fold = Path();


fold.moveTo(
w*0.32,
h*0.40
);


fold.lineTo(
w*0.50,
h*0.52
);


fold.lineTo(
w*0.62,
h*0.62
);


fold.lineTo(
w*0.50,
h*0.70
);


fold.lineTo(
w*0.38,
h*0.55
);


fold.close();



canvas.drawPath(
fold,
dark
);



}



@override
bool shouldRepaint(
covariant CustomPainter oldDelegate
){

return false;

}


}