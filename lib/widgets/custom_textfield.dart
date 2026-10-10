import 'package:flutter/material.dart';



class CustomTextField extends StatelessWidget{


final String hint;

final IconData icon;

final TextEditingController controller;

final bool password;


const CustomTextField({

super.key,

required this.hint,

required this.icon,

required this.controller,

this.password=false

});



@override
Widget build(BuildContext context){


return Padding(

padding:
const EdgeInsets.symmetric(vertical:8),


child:TextField(


controller:controller,


obscureText:password,


decoration:InputDecoration(


prefixIcon:Icon(icon),


hintText:hint,


)


)


);


}

}