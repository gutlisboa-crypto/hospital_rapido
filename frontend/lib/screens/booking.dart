part of '../main.dart';

Future<void> booking(BuildContext context, ApiService api, Appointment? old,
    FutureOr<void> Function() done) async {
  if (MediaQuery.sizeOf(context).width < 600) {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
            body: SafeArea(
                child: BookingPanel(api: api, old: old, onChanged: done)))));
    return;
  }
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => SafeArea(
          child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: FractionallySizedBox(
                      heightFactor: .92,
                      child: BookingPanel(
                          api: api, old: old, onChanged: done))))));
}

enum BookingFilterMode { specialty, professional }

class BookingPanel extends StatefulWidget {
  const BookingPanel(
      {super.key,
      required this.api,
      required this.old,
      required this.onChanged});
  final ApiService api;
  final Appointment? old;
  final FutureOr<void> Function() onChanged;
  @override
  State<BookingPanel> createState() => _BookingPanelState();
}

class _BookingPanelState extends State<BookingPanel> {
  final GlobalKey _timesSectionKey = GlobalKey();
  final GlobalKey _summarySectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> specialties = [], professionals = [];
  List<Map<String, dynamic>> bookingProfessionals = [];
  List<Map<String, dynamic>> professionalSpecialties = [];
  List<DateTime> dates = [];
  List<Slot> times = [];
  String? specialty, error;
  int? doctor;
  DateTime? day;
  Slot? chosen;
  bool loading = true, saving = false, allowPop = false;
  int generation = 0;
  BookingFilterMode filterMode = BookingFilterMode.specialty;

  bool get hasProgress =>
      doctor != null ||
      day != null ||
      chosen != null ||
      (widget.old == null && specialty != null);

  List<String> get stepNames => filterMode == BookingFilterMode.specialty
      ? const ['Especialidade', 'Profissional', 'Data', 'Horário', 'Revisão']
      : const ['Profissional', 'Especialidade', 'Data', 'Horário', 'Revisão'];

  List<Map<String, dynamic>> get visibleSpecialties =>
      filterMode == BookingFilterMode.professional
          ? professionalSpecialties
          : specialties;

  List<Map<String, dynamic>> get visibleProfessionals =>
      filterMode == BookingFilterMode.professional
          ? bookingProfessionals
          : professionals;

  @override
  void initState() {
    super.initState();
    loadSpecialties();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadSpecialties() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.api.specialties();
      if (!mounted) return;
      setState(() {
        specialties = value;
        specialty = widget.old?.specialty;
        loading = false;
      });
      if (specialty != null) loadProfessionals();
    } on ApiException catch (e) {
      showError(e);
    }
  }

  Future<void> loadProfessionals() async {
    final serial = ++generation;
    setState(() {
      loading = true;
      error = null;
      professionals = [];
      doctor = null;
      dates = [];
      day = null;
      times = [];
      chosen = null;
    });
    try {
      final value = await widget.api.professionals(specialty!);
      if (mounted && serial == generation) {
        setState(() {
          professionals = value;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      if (serial == generation) showError(e);
    }
  }

  Future<void> loadBookingProfessionals() async {
    final serial = ++generation;
    setState(() {
      loading = true;
      error = null;
      bookingProfessionals = [];
    });
    try {
      final value = await widget.api.bookingProfessionals();
      if (mounted && serial == generation) {
        setState(() {
          bookingProfessionals = value;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      if (serial == generation) showError(e);
    }
  }

  Future<void> loadSpecialtiesForProfessional() async {
    final serial = ++generation;
    setState(() {
      loading = true;
      error = null;
      professionalSpecialties = [];
      specialty = null;
      dates = [];
      day = null;
      times = [];
      chosen = null;
    });
    try {
      final value = await widget.api.specialtiesForProfessional(doctor!);
      if (mounted && serial == generation) {
        setState(() {
          professionalSpecialties = value;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      if (serial == generation) showError(e);
    }
  }

  Future<void> changeFilterMode(BookingFilterMode mode) async {
    if (filterMode == mode || loading || saving) return;
    generation++;
    setState(() {
      filterMode = mode;
      specialty = null;
      doctor = null;
      professionals = [];
      professionalSpecialties = [];
      dates = [];
      day = null;
      times = [];
      chosen = null;
      error = null;
    });
    await _scrollToStart();
    if (mode == BookingFilterMode.professional &&
        bookingProfessionals.isEmpty) {
      await loadBookingProfessionals();
    }
  }

  Future<void> _scrollToStart() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic);
  }

  Future<void> _reveal(GlobalKey key, {double alignment = .12}) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final targetContext = key.currentContext;
    if (targetContext == null || !targetContext.mounted) return;
    await Scrollable.ensureVisible(targetContext,
        alignment: alignment,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
  }

  Future<void> loadDates() async {
    final serial = ++generation;
    setState(() {
      loading = true;
      error = null;
      dates = [];
      day = null;
      times = [];
      chosen = null;
    });
    try {
      final value = await widget.api.availableDates(specialty!, doctor!);
      if (mounted && serial == generation) {
        setState(() {
          dates = value;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      if (serial == generation) showError(e);
    }
  }

  Future<void> loadTimes() async {
    final serial = ++generation;
    setState(() {
      loading = true;
      error = null;
      times = [];
      chosen = null;
    });
    try {
      final value = await widget.api.availableTimes(specialty!, doctor!, day!);
      if (mounted && serial == generation) {
        setState(() {
          times = value;
          loading = false;
        });
        await _reveal(_timesSectionKey);
      }
    } on ApiException catch (e) {
      if (serial == generation) showError(e);
    }
  }

  Future<void> selectNextAvailableDate() async {
    if (dates.isEmpty || loading || saving) return;
    setState(() => day = dates.first);
    await loadTimes();
  }

  Future<void> showTimeOptions() async {
    await _reveal(_timesSectionKey);
  }

  void selectTime(Slot slot) {
    setState(() => chosen = slot);
    _reveal(_summarySectionKey, alignment: .35);
  }

  void showError(ApiException e) {
    if (!mounted) return;
    setState(() {
      error = e.message;
      loading = false;
    });
  }

  Future<void> requestClose() async {
    if (saving) return;
    var discard = !hasProgress;
    if (!discard) {
      discard = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Sair do agendamento?'),
              content: const Text(
                  'A especialidade, o profissional, a data e o horário selecionados serão descartados.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Continuar agendamento')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Descartar seleção')),
              ],
            ),
          ) ??
          false;
    }
    if (!discard || !mounted) return;
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> confirm() async {
    if (chosen == null || saving) return;
    setState(() => saving = true);
    try {
      if (widget.old == null) {
        await widget.api.book(chosen!);
      } else {
        await widget.api.reschedule(widget.old!.id, chosen!);
      }
      await widget.onChanged();
      if (mounted) {
        allowPop = true;
        final success = widget.old == null
            ? 'Consulta agendada com sucesso'
            : 'Consulta reagendada com sucesso';
        announceImportant(context, success);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(
            content: Semantics(container: true, child: Text(success))));
      }
    } on ApiException catch (e) {
      if (mounted) {
        final occupied = e.statusCode == 409 ||
            e.message.toLowerCase().contains('indisponível') ||
            e.message.toLowerCase().contains('disponível');
        setState(() => error = occupied
            ? 'Horário indisponível. Escolha outro horário'
            : e.message);
        if (occupied) notice(context, error!);
        if (occupied && day != null) await loadTimes();
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  int get currentStep => chosen != null
      ? 4
      : day != null
          ? 3
          : doctor != null && specialty != null
              ? 2
              : (filterMode == BookingFilterMode.specialty
                      ? specialty != null
                      : doctor != null)
                  ? 1
                  : 0;

  Widget _availabilityMessage(BuildContext context, String message) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Text(message,
          style:
              Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)));

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: allowPop || !hasProgress,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) requestClose();
      },
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 600;
        final specialtyOptions = uniqueSpecialtyOptions(visibleSpecialties);
        return FormTypography(
            child: Padding(
                padding: EdgeInsets.only(
                    left: compact ? 16 : 28,
                    right: compact ? 16 : 28,
                    top: compact ? 16 : 24,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                widget.old == null
                                    ? 'Agendar consulta'
                                    : 'Reagendar consulta',
                                style:
                                    Theme.of(context).textTheme.headlineSmall)),
                        IconButton(
                            tooltip: 'Fechar',
                            onPressed: saving ? null : requestClose,
                            icon: const Icon(Icons.close))
                      ]),
                      Semantics(
                        container: true,
                        label:
                            'Etapa ${currentStep + 1} de 5: ${stepNames[currentStep]}',
                        value: '${currentStep + 1} de 5',
                        child: Text(
                            'Etapa ${currentStep + 1} de 5 · ${stepNames[currentStep]}',
                            key: const Key('booking-progress-label'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    fontSize: 18,
                                    color: accessibility.highContrast
                                        ? null
                                        : blue,
                                    fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: (currentStep + 1) / 5),
                      const SizedBox(height: 12),
                      Expanded(
                          child: ListView(
                              controller: _scrollController,
                              children: [
                            if (widget.old == null) ...[
                              Text('Como prefere começar?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<BookingFilterMode>(
                                  key: const Key('booking-filter-mode'),
                                  showSelectedIcon: true,
                                  segments: const [
                                    ButtonSegment(
                                        value: BookingFilterMode.specialty,
                                        label: Text('Especialidade')),
                                    ButtonSegment(
                                        value: BookingFilterMode.professional,
                                        label: Text('Profissional')),
                                  ],
                                  selected: {filterMode},
                                  onSelectionChanged: loading || saving
                                      ? null
                                      : (selection) =>
                                          changeFilterMode(selection.first),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                filterMode == BookingFilterMode.specialty
                                    ? 'Escolha a área de atendimento e depois um profissional disponível.'
                                    : 'Escolha quem fará o atendimento e depois uma especialidade disponível.',
                                key: const Key('booking-filter-guidance'),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            if (filterMode == BookingFilterMode.professional &&
                                bookingProfessionals.isNotEmpty)
                              Semantics(
                                  label: 'Profissional para agendamento',
                                  child: DropdownButtonFormField<int>(
                                      key: const Key(
                                          'booking-professional-first'),
                                      isExpanded: true,
                                      itemHeight: null,
                                      initialValue: doctor,
                                      decoration: const InputDecoration(
                                          labelText: '1. Profissional',
                                          helperText:
                                              'Selecione o profissional para ver as especialidades.'),
                                      items: bookingProfessionals
                                          .map((x) => DropdownMenuItem(
                                              value: x['id'] as int,
                                              child: Text(x['name'] as String,
                                                  softWrap: true, maxLines: 2)))
                                          .toList(),
                                      onChanged: loading || saving
                                          ? null
                                          : (v) {
                                              if (v == null) return;
                                              setState(() => doctor = v);
                                              loadSpecialtiesForProfessional();
                                            })),
                            if (!loading &&
                                filterMode == BookingFilterMode.professional &&
                                bookingProfessionals.isEmpty &&
                                error == null)
                              _availabilityMessage(context,
                                  'Nenhum profissional ativo está disponível para agendamento.'),
                            if (filterMode == BookingFilterMode.professional &&
                                doctor != null)
                              const SizedBox(height: AppSpacing.md),
                            if (specialtyOptions.isNotEmpty &&
                                (filterMode == BookingFilterMode.specialty ||
                                    doctor != null))
                              Semantics(
                                  label: 'Especialidade para agendamento',
                                  child: DropdownButtonFormField<String>(
                                      key: const Key('booking-specialty'),
                                      isExpanded: true,
                                      itemHeight: null,
                                      initialValue: specialty,
                                      decoration: InputDecoration(
                                          labelText: filterMode ==
                                                  BookingFilterMode.specialty
                                              ? '1. Especialidade'
                                              : '2. Especialidade',
                                          helperText: filterMode ==
                                                  BookingFilterMode.specialty
                                              ? 'Selecione a área de atendimento.'
                                              : 'Selecione a especialidade atendida por este profissional.'),
                                      items: specialtyOptions
                                          .map((x) => DropdownMenuItem(
                                              value: x['name'] as String,
                                              child: Text(
                                                  specialtyDisplayName(
                                                      x['name'] as String),
                                                  softWrap: true,
                                                  maxLines: 2)))
                                          .toList(),
                                      onChanged: loading ||
                                              saving ||
                                              widget.old != null
                                          ? null
                                          : (v) {
                                              if (v == null) {
                                                return;
                                              }
                                              setState(() => specialty = v);
                                              if (filterMode ==
                                                  BookingFilterMode.specialty) {
                                                loadProfessionals();
                                              } else {
                                                loadDates();
                                              }
                                            })),
                            if (!loading &&
                                filterMode == BookingFilterMode.specialty &&
                                specialties.isEmpty &&
                                error == null)
                              _availabilityMessage(context,
                                  'Nenhuma especialidade ativa disponível para agendamento.'),
                            const SizedBox(height: 12),
                            if (!loading &&
                                filterMode == BookingFilterMode.professional &&
                                doctor != null &&
                                professionalSpecialties.isEmpty &&
                                error == null)
                              _availabilityMessage(context,
                                  'Este profissional não possui especialidades disponíveis para agendamento.'),
                            const SizedBox(height: 12),
                            if (filterMode == BookingFilterMode.specialty &&
                                specialty != null &&
                                professionals.isNotEmpty)
                              Semantics(
                                  label: 'Profissional para agendamento',
                                  child: DropdownButtonFormField<int>(
                                      key: ValueKey('doctor-$specialty'),
                                      isExpanded: true,
                                      itemHeight: null,
                                      initialValue: doctor,
                                      decoration: const InputDecoration(
                                          labelText: '2. Profissional',
                                          helperText:
                                              'Selecione quem fará o atendimento.'),
                                      items: professionals
                                          .map((x) => DropdownMenuItem(
                                              value: x['id'] as int,
                                              child: Text(x['name'] as String,
                                                  softWrap: true, maxLines: 2)))
                                          .toList(),
                                      onChanged: loading || saving
                                          ? null
                                          : (v) {
                                              if (v == null) {
                                                return;
                                              }
                                              setState(() => doctor = v);
                                              loadDates();
                                            })),
                            if (!loading &&
                                filterMode == BookingFilterMode.specialty &&
                                specialty != null &&
                                professionals.isEmpty &&
                                error == null)
                              _availabilityMessage(context,
                                  'Nenhum profissional ativo vinculado a esta especialidade.'),
                            const SizedBox(height: 12),
                            if (doctor != null && dates.isNotEmpty)
                              Row(children: [
                                Expanded(
                                    child: Semantics(
                                        label: 'Data para agendamento',
                                        child: DropdownButtonFormField<
                                                DateTime>(
                                            key: ValueKey('date-$doctor'),
                                            isExpanded: true,
                                            itemHeight: null,
                                            initialValue: day,
                                            decoration: const InputDecoration(
                                                labelText: '3. Data disponível',
                                                helperText:
                                                    'Escolha o dia da consulta.'),
                                            items: dates
                                                .map((x) => DropdownMenuItem(
                                                    value: x,
                                                    child: Text(
                                                        showBookingDate(x),
                                                        softWrap: true,
                                                        maxLines: 2)))
                                                .toList(),
                                            onChanged: loading || saving
                                                ? null
                                                : (v) {
                                                    if (v == null) {
                                                      return;
                                                    }
                                                    setState(() => day = v);
                                                    loadTimes();
                                                  }))),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                    key: const Key('next-available-date'),
                                    tooltip: 'Próxima data disponível',
                                    onPressed: loading || saving
                                        ? null
                                        : selectNextAvailableDate,
                                    icon: const Icon(
                                        Icons.event_available_outlined))
                              ]),
                            if (!loading &&
                                doctor != null &&
                                dates.isEmpty &&
                                error == null)
                              _availabilityMessage(context,
                                  'Não há vagas disponíveis para este profissional. Tente outro filtro.'),
                            const SizedBox(height: 12),
                            if (day != null && times.isNotEmpty) ...[
                              Text('4. Escolha um horário',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                  '${times.where((slot) => slot.selectable).length} horários disponíveis para ${showBookingDate(day!)}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: AppSpacing.md),
                              _BookingTimeGroups(
                                  key: _timesSectionKey,
                                  slots: times,
                                  selected: chosen,
                                  saving: saving,
                                  onSelected: selectTime),
                            ],
                            if (!loading &&
                                day != null &&
                                times.isEmpty &&
                                error == null)
                              _availabilityMessage(context,
                                  'Não há horários livres nesta data. Escolha outra data.'),
                            if (loading)
                              const Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator())),
                            if (error != null)
                              Column(children: [
                                InfoPanel(
                                    icon: Icons.error_outline, text: error!),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                    onPressed: () {
                                      if (day != null) {
                                        loadTimes();
                                      } else if (doctor != null) {
                                        if (specialty != null) {
                                          loadDates();
                                        } else if (filterMode ==
                                            BookingFilterMode.professional) {
                                          loadSpecialtiesForProfessional();
                                        }
                                      } else if (specialty != null) {
                                        loadProfessionals();
                                      } else if (filterMode ==
                                          BookingFilterMode.professional) {
                                        loadBookingProfessionals();
                                      } else {
                                        loadSpecialties();
                                      }
                                    },
                                    child: const Text('Tentar novamente'))
                              ]),
                            if (chosen != null)
                              KeyedSubtree(
                                key: _summarySectionKey,
                                child: _BookingSummary(
                                    key: const Key('booking-summary'),
                                    specialty: specialtyDisplayName(specialty!),
                                    professional: visibleProfessionals
                                            .firstWhere((item) =>
                                                item['id'] == doctor)['name']
                                        as String,
                                    scheduledAt: chosen!.scheduledAt,
                                    rescheduling: widget.old != null,
                                    onChangeTime: showTimeOptions),
                              ),
                            const SizedBox(
                                key: Key('booking-summary-scroll-end'),
                                height: AppSpacing.lg),
                          ])),
                      SafeArea(
                          top: false,
                          minimum: const EdgeInsets.only(top: AppSpacing.sm),
                          child: AppActionButton(
                              label: widget.old == null
                                  ? 'Confirmar agendamento'
                                  : 'Confirmar reagendamento',
                              semanticLabel: widget.old == null
                                  ? 'Agendar consulta'
                                  : 'Reagendar consulta',
                              icon: Icons.event_available_outlined,
                              onPressed: chosen == null || loading || saving
                                  ? null
                                  : confirm,
                              busy: saving,
                              expand: true)),
                    ])));
      }));
}

String showBookingDate(DateTime date) {
  const weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]} de ${date.year}';
}

String showBookingSummaryDate(DateTime date) {
  const weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]} de ${date.year} · $time';
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    super.key,
    required this.specialty,
    required this.professional,
    required this.scheduledAt,
    required this.rescheduling,
    required this.onChangeTime,
  });

  final String specialty;
  final String professional;
  final DateTime scheduledAt;
  final bool rescheduling;
  final VoidCallback onChangeTime;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title = rescheduling ? 'Seu novo horário' : 'Sua consulta';
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: accessibility.highContrast
              ? colors.surface
              : colors.primaryContainer.withValues(alpha: .38),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: accessibility.highContrast
                  ? colors.onSurface
                  : colors.primary.withValues(alpha: .42)),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accessibility.highContrast
                        ? colors.surface
                        : colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.event_available_outlined,
                      color: colors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Revise os dados antes de confirmar.',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(showBookingSummaryDate(scheduledAt),
                key: const Key('booking-summary-date-time'),
                style: textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.2)),
            const SizedBox(height: AppSpacing.md),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 560 ||
                  accessibility.fontSizeScale > 1.15;
              final itemWidth = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - AppSpacing.md) / 2;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _BookingSummaryDetail(
                        icon: Icons.medical_services_outlined,
                        label: 'Especialidade',
                        value: specialty),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _BookingSummaryDetail(
                        icon: Icons.person_outline,
                        label: 'Profissional',
                        value: professional),
                  ),
                ],
              );
            }),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                    key: const Key('change-booking-time'),
                    onPressed: onChangeTime,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Alterar horário')),
                Text('A reserva será concluída ao confirmar.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingSummaryDetail extends StatelessWidget {
  const _BookingSummaryDetail(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingTimeGroups extends StatelessWidget {
  const _BookingTimeGroups({
    super.key,
    required this.slots,
    required this.selected,
    required this.saving,
    required this.onSelected,
  });

  final List<Slot> slots;
  final Slot? selected;
  final bool saving;
  final ValueChanged<Slot> onSelected;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Slot>>{
      'Manhã': slots.where((slot) => slot.scheduledAt.hour < 12).toList(),
      'Tarde': slots
          .where((slot) =>
              slot.scheduledAt.hour >= 12 && slot.scheduledAt.hour < 18)
          .toList(),
      'Noite': slots.where((slot) => slot.scheduledAt.hour >= 18).toList(),
    };
    final visibleGroups =
        groups.entries.where((entry) => entry.value.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in visibleGroups) ...[
          Text(entry.key,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          _BookingTimeGrid(
              slots: entry.value,
              selected: selected,
              saving: saving,
              onSelected: onSelected),
          if (entry.key != visibleGroups.last.key)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _BookingTimeGrid extends StatelessWidget {
  const _BookingTimeGrid({
    required this.slots,
    required this.selected,
    required this.saving,
    required this.onSelected,
  });

  final List<Slot> slots;
  final Slot? selected;
  final bool saving;
  final ValueChanged<Slot> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, grid) {
        final scale = accessibility.fontSizeScale;
        final preferredColumns = grid.maxWidth >= 700
            ? 5
            : grid.maxWidth >= 480
                ? 3
                : grid.maxWidth >= 320 && scale <= 1.15
                    ? 2
                    : 1;
        final columns =
            preferredColumns < slots.length ? preferredColumns : slots.length;
        final cardWidth = (grid.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final slot in slots)
            SizedBox(
                width: cardWidth,
                child: AvailabilitySlotCard(
                    slot: slot,
                    selected: selected?.scheduledAt == slot.scheduledAt,
                    onPressed: saving || !slot.selectable
                        ? null
                        : () => onSelected(slot))),
        ]);
      });
}
