import 'package:flutter/material.dart';
import 'note.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Note> notes = [];
  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //appTitle at the top of the screen
        title: const Text("NOTES", style: TextStyle(fontSize: 23)),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          return ListTile(
            //only showing the title on the home page
            title: Text(notes[index].title),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Add Note"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: "Enter title",
                      ),
                    ),
                    TextField(
                      controller: bodyController,
                      decoration: const InputDecoration(hintText: "Enter body"),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      //will close the popup
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        //saves the note
                        notes.add(Note(title: titleController.text, body: ""));
                      });
                      //clear the text box for the next note
                      titleController.clear();

                      // close the popup
                      Navigator.pop(context);
                    },
                    child: const Text("Save"),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
