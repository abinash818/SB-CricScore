import 'package:flutter/material.dart';
import '../../core/api_service.dart';

class TournamentCreateScreen extends StatefulWidget {
  const TournamentCreateScreen({super.key});

  @override
  State<TournamentCreateScreen> createState() => _TournamentCreateScreenState();
}

class _TournamentCreateScreenState extends State<TournamentCreateScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _oversController = TextEditingController(text: '20');
  final _wicketsController = TextEditingController(text: '10');
  final _winPointsController = TextEditingController(text: '2');
  final _tiePointsController = TextEditingController(text: '1');
  final _nrPointsController = TextEditingController(text: '1');
  final _lossPointsController = TextEditingController(text: '0');

  String _formatType = 'round_robin';
  final List<TextEditingController> _teamControllers = [
    TextEditingController(text: 'Team A'),
    TextEditingController(text: 'Team B'),
  ];

  bool _isSubmitting = false;
  String? _errorMessage;

  void _addTeamField() {
    setState(() {
      _teamControllers.add(TextEditingController(text: 'Team ${String.fromCharCode(65 + _teamControllers.length)}'));
    });
  }

  void _removeTeamField(int index) {
    if (_teamControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 teams are required')),
      );
      return;
    }
    setState(() {
      _teamControllers.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final List<String> teams = _teamControllers
        .map((c) => c.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    try {
      final res = await _apiService.createTournament(
        name: _nameController.text.trim(),
        type: _formatType,
        defaultOvers: int.tryParse(_oversController.text) ?? 20,
        defaultWickets: int.tryParse(_wicketsController.text) ?? 10,
        winPoints: int.tryParse(_winPointsController.text) ?? 2,
        tiePoints: int.tryParse(_tiePointsController.text) ?? 1,
        nrPoints: int.tryParse(_nrPointsController.text) ?? 1,
        lossPoints: int.tryParse(_lossPointsController.text) ?? 0,
        teams: teams,
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🏆 Tournament created successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to create tournament';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF070710);
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Tournament',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                ),

              // Tournament Name Card
              _buildSectionCard(
                title: '📌 Basic Details',
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Tournament Name (e.g. Astro Cup 2026)'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter tournament name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _formatType,
                    isExpanded: true,
                    dropdownColor: cardBg,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Format Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'round_robin',
                        child: Text(
                          '🔄 Round Robin (League + Knockout)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'knockout',
                        child: Text(
                          '⚡ Direct Knockout (Elimination)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _formatType = val);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Match & Points Setup
              _buildSectionCard(
                title: '⚙️ Rules & Over Defaults',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _oversController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Default Overs'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _wicketsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Default Wickets'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _winPointsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Win Points'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _tiePointsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Tie Points'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Participating Teams Card
              _buildSectionCard(
                title: '🛡️ Initial Teams',
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _teamControllers.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _teamControllers[index],
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('Team ${index + 1} Name'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _removeTeamField(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addTeamField,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: const BorderSide(color: goldColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('+ Add Another Team'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                        )
                      : const Text(
                          '🚀 Create Tournament',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    const goldColor = Color(0xFFDFBA73);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF070710),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: goldColor.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: goldColor.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: goldColor),
      ),
    );
  }
}
