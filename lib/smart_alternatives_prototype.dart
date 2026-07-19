import 'package:flutter/material.dart';

// 1. Domain Models
class Exercise {
  final String name;
  final List<String> primaryMuscles;
  final List<String> equipment;

  const Exercise({
    required this.name,
    required this.primaryMuscles,
    required this.equipment,
  });
}

// 2. Mock Data (Matches our Seed JSON)
const List<Exercise> mockDatabase = [
  Exercise(name: "Barbell Bench Press", primaryMuscles: ["Pectoralis major"], equipment: ["Barbell", "Bench"]),
  Exercise(name: "Dumbbell Bench Press", primaryMuscles: ["Pectoralis major"], equipment: ["Dumbbell", "Bench"]),
  Exercise(name: "Smith Machine Bench Press", primaryMuscles: ["Pectoralis major"], equipment: ["Smith Machine", "Bench"]),
  Exercise(name: "Cable Crossover", primaryMuscles: ["Pectoralis major"], equipment: ["Cable"]),
  Exercise(name: "Pec Deck", primaryMuscles: ["Pectoralis major"], equipment: ["Machine"]),
  Exercise(name: "Push-up", primaryMuscles: ["Pectoralis major"], equipment: ["Bodyweight"]),
  Exercise(name: "Barbell Squat", primaryMuscles: ["Quadriceps", "Gluteus maximus"], equipment: ["Barbell", "Squat Rack"]),
];

// 3. The Algorithm
List<Exercise> getSmartAlternatives(Exercise occupiedExercise) {
  // Global Priority Chain
  const priorityChain = [
    "Barbell",
    "Smith Machine",
    "Cable",
    "Machine",
    "Dumbbell",
    "Bodyweight"
  ];

  // Filter 1: Exact Primary Muscle Match (ignoring the occupied exercise itself)
  final viable = mockDatabase.where((ex) {
    if (ex.name == occupiedExercise.name) return false;
    
    // Check if any primary muscle matches
    return ex.primaryMuscles.any((m) => occupiedExercise.primaryMuscles.contains(m));
  }).toList();

  // Determine the starting equipment of the occupied exercise
  String startingEquip = occupiedExercise.equipment.firstWhere(
    (e) => priorityChain.contains(e), 
    orElse: () => priorityChain.first
  );

  int startIndex = priorityChain.indexOf(startingEquip);
  
  // Create a custom sorted priority list that wraps around
  // E.g., if starting is "Cable", order is: Cable, Machine, Dumbbell, Bodyweight, Barbell, Smith Machine
  List<String> wrapAroundPriority = [
    ...priorityChain.sublist(startIndex),
    ...priorityChain.sublist(0, startIndex)
  ];

  // Sort the viable list based on this new priority
  viable.sort((a, b) {
    String equipA = a.equipment.firstWhere((e) => wrapAroundPriority.contains(e), orElse: () => 'Bodyweight');
    String equipB = b.equipment.firstWhere((e) => wrapAroundPriority.contains(e), orElse: () => 'Bodyweight');
    
    return wrapAroundPriority.indexOf(equipA).compareTo(wrapAroundPriority.indexOf(equipB));
  });

  return viable;
}

// 4. Prototype UI
void main() {
  runApp(const MaterialApp(home: PrototypeScreen()));
}

class PrototypeScreen extends StatefulWidget {
  const PrototypeScreen({super.key});

  @override
  State<PrototypeScreen> createState() => _PrototypeScreenState();
}

class _PrototypeScreenState extends State<PrototypeScreen> {
  Exercise currentExercise = mockDatabase[0]; // Start with Barbell Bench Press
  bool isSkipped = false;

  void _showAlternatives() {
    final alternatives = getSmartAlternatives(currentExercise);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Smart Alternatives', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: alternatives.length,
                  itemBuilder: (context, index) {
                    final alt = alternatives[index];
                    return ListTile(
                      title: Text(alt.name),
                      subtitle: Text(alt.equipment.join(', ')),
                      trailing: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentExercise = alt;
                            isSkipped = false;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Swap'),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      setState(() {
                        isSkipped = true;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Skip Exercise'),
                  ),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Algorithm Prototype')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSkipped)
              const Text('EXERCISE SKIPPED', style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold))
            else ...[
              const Text('Current Active Exercise:'),
              Text(currentExercise.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Equipment: ${currentExercise.equipment.join(', ')}'),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.warning),
                label: const Text('Occupied! Find Alternative'),
                onPressed: _showAlternatives,
              ),
            ],
            const SizedBox(height: 60),
            TextButton(
              onPressed: () {
                setState(() {
                  currentExercise = mockDatabase.firstWhere((e) => e.name == "Cable Crossover");
                  isSkipped = false;
                });
              },
              child: const Text('Reset to Cable Crossover (To test wrap-around)'),
            )
          ],
        ),
      ),
    );
  }
}
