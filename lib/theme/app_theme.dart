import 'package:flutter/material.dart';


class AppTheme{


static ThemeData theme = ThemeData(


useMaterial3:true,


fontFamily:"Poppins",


colorScheme:ColorScheme.fromSeed(

seedColor:Colors.blue

),


inputDecorationTheme:InputDecorationTheme(


filled:true,


fillColor:Colors.white,


border:OutlineInputBorder(

borderRadius:BorderRadius.circular(18),

borderSide:BorderSide.none

)


)


);


}