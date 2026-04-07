import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api_client.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

// ─── Quiz List Screen ─────────────────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizModel> _quizzes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = await api.getAvailableQuizzes();
      setState(() { _quizzes = q; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: const Text('Quizzes'),
        backgroundColor: AppColors.sage800,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : !auth.isAuthenticated
                  ? const EmptyState(
                      icon: Icons.quiz_outlined,
                      title: 'Sign in to take quizzes',
                      subtitle: 'Quizzes are available after enrolling in a course.',
                    )
                  : _quizzes.isEmpty
                      ? const EmptyState(
                          icon: Icons.quiz_outlined,
                          title: 'No quizzes available',
                          subtitle: 'Enroll in more courses to unlock quizzes.',
                        )
                      : RefreshIndicator(
                          color: AppColors.sage600,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _quizzes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _QuizCard(quiz: _quizzes[i]),
                          ),
                        ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizModel quiz;
  const _QuizCard({required this.quiz});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => QuizPlayScreen(quiz: quiz))),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage100),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.sage100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.quiz_rounded, color: AppColors.sage600, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quiz.title, style: AppTextStyles.h3),
                if (quiz.description != null) ...[
                  const SizedBox(height: 4),
                  Text(quiz.description!, style: AppTextStyles.body.copyWith(color: AppColors.grey400),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (quiz.totalQuestions != null) ...[
                  const SizedBox(height: 6),
                  Text('${quiz.totalQuestions} questions',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.sage500)),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.grey400),
        ],
      ),
    ),
  );
}

// ─── Quiz Play Screen ─────────────────────────────────────────────────────────

class QuizPlayScreen extends StatefulWidget {
  final QuizModel quiz;
  const QuizPlayScreen({super.key, required this.quiz});
  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  List<QuizQuestion> _questions = [];
  int? _attemptId;
  bool _loading = true;
  String? _error;
  int _current = 0;
  final Map<int, dynamic> _answers = {};
  final _stopwatch = Stopwatch();
  QuizResult? _result;
  bool _submitting = false;

  @override
  void initState() { super.initState(); _start(); }

  Future<void> _start() async {
    try {
      final data = await api.startQuiz(widget.quiz.id);
      final questions = (data['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q)).toList();
      final attemptId = data['attempt']?['id'] as int?;
      setState(() {
        _questions = questions;
        _attemptId = attemptId;
        _loading = false;
      });
      _stopwatch.start();
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _submit() async {
    if (_attemptId == null) return;
    setState(() => _submitting = true);
    _stopwatch.stop();
    try {
      final answers = _answers.map((k, v) => MapEntry(k.toString(), v));
      final result = await api.submitQuiz(_attemptId!, answers, _stopwatch.elapsed.inSeconds);
      setState(() { _result = result; _submitting = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _submitting = false; });
    }
  }

  void _selectAnswer(int questionId, dynamic value) =>
      setState(() => _answers[questionId] = value);

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildResult();
    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: Text(widget.quiz.title),
        backgroundColor: AppColors.sage800,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 20, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _start)
              : _buildQuiz(),
    );
  }

  Widget _buildQuiz() {
    if (_questions.isEmpty) return const EmptyState(icon: Icons.quiz_outlined, title: 'No questions');
    final q = _questions[_current];
    final answered = _answers.length;
    final progress = _questions.isNotEmpty ? _current / _questions.length : 0.0;

    return Column(
      children: [
        // Progress bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Question ${_current + 1} of ${_questions.length}',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.grey400)),
                  Text('$answered answered',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.sage600)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.sage100,
                  valueColor: const AlwaysStoppedAnimation(AppColors.sage600),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        // Question
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.question, style: AppTextStyles.h2.copyWith(height: 1.5)),
                const SizedBox(height: 24),
                if (q.type == 'short_answer')
                  _ShortAnswerInput(
                    value: _answers[q.id] as String?,
                    onChanged: (v) => _selectAnswer(q.id, v),
                  )
                else
                  ...q.options.map((opt) => _OptionTile(
                    option: opt,
                    selected: q.type == 'multiple_response'
                        ? (_answers[q.id] as List? ?? []).contains(opt.id.toString())
                        : _answers[q.id] == opt.id,
                    onTap: () {
                      if (q.type == 'multiple_response') {
                        final current = List<String>.from(_answers[q.id] as List? ?? []);
                        final idStr = opt.id.toString();
                        if (current.contains(idStr)) current.remove(idStr);
                        else current.add(idStr);
                        _selectAnswer(q.id, current);
                      } else {
                        _selectAnswer(q.id, opt.id);
                      }
                    },
                  )),
              ],
            ),
          ),
        ),

        // Navigation
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              if (_current > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _current--),
                    child: const Text('Previous'),
                  ),
                ),
              if (_current > 0) const SizedBox(width: 12),
              Expanded(
                child: _current < _questions.length - 1
                    ? ElevatedButton(
                        onPressed: () => setState(() => _current++),
                        child: const Text('Next'),
                      )
                    : ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage700),
                        child: _submitting
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit quiz'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final passed = r.passed;
    return Scaffold(
      backgroundColor: AppColors.sage50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: passed ? AppColors.sage100 : const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
                  size: 52,
                  color: passed ? AppColors.sage600 : AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                passed ? 'Well done!' : 'Keep practising',
                style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 32, color: AppColors.sage900),
              ),
              const SizedBox(height: 8),
              Text(
                '${r.score} / ${r.total} correct  •  ${r.percentage.toStringAsFixed(0)}%',
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.grey600),
              ),
              const SizedBox(height: 40),
              PrimaryButton(
                label: 'Back to quizzes',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'View leaderboard',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => LeaderboardScreen(quizId: widget.quiz.id))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final QuizOption option;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.sage50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.sage600 : AppColors.sage200,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: selected ? AppColors.sage600 : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? AppColors.sage600 : AppColors.grey400),
            ),
            child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(option.text, style: AppTextStyles.body)),
        ],
      ),
    ),
  );
}

class _ShortAnswerInput extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const _ShortAnswerInput({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: TextEditingController(text: value),
    onChanged: onChanged,
    maxLines: 4,
    style: AppTextStyles.body,
    decoration: InputDecoration(
      hintText: 'Type your answer here…',
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.sage200)),
    ),
  );
}

// ─── Leaderboard Screen ───────────────────────────────────────────────────────

class LeaderboardScreen extends StatefulWidget {
  final int? quizId;
  const LeaderboardScreen({super.key, this.quizId});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await api.getLeaderboard(quizId: widget.quizId);
      setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = (_data?['leaderboard'] ?? _data?['data'] ?? []) as List;
    return Scaffold(
      backgroundColor: AppColors.sage50,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: AppColors.sage800,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : entries.isEmpty
                  ? const EmptyState(icon: Icons.leaderboard_outlined, title: 'No scores yet')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final e = entries[i] as Map<String, dynamic>;
                        final rank = i + 1;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: rank <= 3 ? AppColors.warm50 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: rank <= 3 ? AppColors.warm300 : AppColors.sage100),
                          ),
                          child: Row(
                            children: [
                              Text(
                                rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                                style: TextStyle(fontSize: rank <= 3 ? 24 : 16,
                                    fontWeight: FontWeight.w700, color: AppColors.sage700),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(e['user']?['name'] ?? e['name'] ?? 'Student',
                                    style: AppTextStyles.h3),
                              ),
                              Text('${e['score'] ?? e['percentage'] ?? 0}%',
                                  style: AppTextStyles.h3.copyWith(color: AppColors.sage600)),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
