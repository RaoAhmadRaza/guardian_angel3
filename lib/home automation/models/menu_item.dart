import 'package:rive/rive.dart';

class MenuItemModel {
  final String id;
  final String title;
  final String artboard;
  final String stateMachine;
  SMIBool? input;

  MenuItemModel(this.id, this.title, this.artboard, this.stateMachine);
}

final menuItems = [
  MenuItemModel("home", "Home", "HOME", "HOME_interactivity"),
  MenuItemModel("rooms", "Rooms", "SEARCH", "SEARCH_Interactivity"),
];
