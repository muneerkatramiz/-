import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'requests.dart';

class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.approvedProvider) {
      final rejected = s.providerStatus == 'rejected';
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('tab_provider'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(rejected ? Icons.block : Icons.hourglass_top, size: 52, color: rejected ? Colors.red.shade700 : kGold),
              const SizedBox(height: 14),
              Text(context.tr(rejected ? 'prov_rejected' : 'prov_pending'), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await s.refreshUser();
                  } catch (e) {
                    if (context.mounted) snack(context, errText(e));
                  }
                },
                child: Text(context.tr('refresh')),
              ),
            ]),
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('tab_provider')),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: kGold,
            tabs: [Tab(text: context.tr('open_requests')), Tab(text: context.tr('my_offers')), Tab(text: context.tr('vehicles'))],
          ),
        ),
        body: const TabBarView(children: [_OpenRequests(), _MyOffers(), _Vehicles()]),
      ),
    );
  }
}

class _OpenRequests extends StatelessWidget {
  const _OpenRequests();
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return DataView<List<Json>>(
      load: () => s.api.providerRequests(),
      builder: (c, list, reload) {
        if (list.isEmpty) return EmptyView(c.tr('nothing'));
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c2, i) {
            final r = list[i];
            final sent = r['my_offer_id'] != null;
            return Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('#${r['id']}  ${s.localized(r['service_name'])}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (sent) Text(c2.tr('offer_sent'), style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                ]),
                if (routeText(r).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(routeText(r))),
                if (fmtDate(r['service_date'] as String?).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(fmtDate(r['service_date'] as String?), style: const TextStyle(color: Colors.black54))),
                if ((r['quantity'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c2.tr('quantity')}: ${r['quantity']}', style: const TextStyle(color: Colors.black54))),
                if ((r['details'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r['details'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 10),
                FilledButton(onPressed: () => showOfferSheet(c2, r), child: Text(c2.tr(sent ? 'edit_offer' : 'send_offer'))),
              ]),
            );
          },
        );
      },
    );
  }
}

Future<void> showOfferSheet(BuildContext context, Json req) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (b) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(b).viewInsets.bottom + 16),
      child: _OfferForm(req: req),
    ),
  );
}

class _OfferForm extends StatefulWidget {
  final Json req;
  const _OfferForm({required this.req});
  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  final _amount = TextEditingController();
  final _msg = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    final amt = _amount.text.trim().replaceAll(',', '.');
    if (double.tryParse(amt) == null || double.parse(amt) <= 0) {
      snack(context, context.tr('required'));
      return;
    }
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    final msgr = ScaffoldMessenger.of(context);
    final done = context.tr('offer_sent');
    setState(() => _busy = true);
    try {
      await s.api.sendOffer(widget.req['id'] as int, amt, _msg.text.trim());
      s.bump();
      nav.pop();
      msgr.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('#${widget.req['id']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 12),
      TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.tr('price_kwd'))),
      const SizedBox(height: 12),
      TextField(controller: _msg, maxLines: 3, decoration: InputDecoration(labelText: context.tr('message_opt'))),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _busy ? null : _send,
        child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.tr('send_offer')),
      ),
    ]);
  }
}

class _MyOffers extends StatelessWidget {
  const _MyOffers();
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return DataView<List<Json>>(
      load: () => s.api.providerOffers(),
      builder: (c, list, reload) {
        if (list.isEmpty) return EmptyView(c.tr('nothing'));
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c2, i) {
            final o = list[i];
            final r = o['request'] == null ? null : Map<String, dynamic>.from(o['request'] as Map);
            return Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r == null ? '#${o['request_id']}' : '#${r['id']}  ${s.localized(r['service_name'])}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  StatusChip(o['status'] as String),
                ]),
                if (r != null && routeText(r).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(routeText(r))),
                const SizedBox(height: 6),
                Text(fmtMoney(o['amount'], o['currency']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (r != null && o['status'] == 'accepted' && r['customer_phone'] != null) ...[
                  const SizedBox(height: 8),
                  Text('${c2.tr('customer')}: ${r['customer_name'] ?? ''}'),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(onPressed: () => openUrl('tel:${r['customer_phone']}'), icon: const Icon(Icons.call), label: Text('${c2.tr('call')}  ${r['customer_phone']}')),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

class _Vehicles extends StatelessWidget {
  const _Vehicles();

  Future<void> _add(BuildContext context) async {
    final s = context.read<AppState>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (b) => const _VehicleForm(),
    );
    if (ok == true) s.bump();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGold,
        foregroundColor: kGreen,
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('add_vehicle')),
      ),
      body: DataView<List<Json>>(
        load: () => s.api.vehicles(),
        builder: (c, list, reload) {
          if (list.isEmpty) return EmptyView(c.tr('nothing'));
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (c2, i) {
              final v = list[i];
              final photos = ((v['photos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
              final parts = [v['model'], v['plate'], v['capacity']].where((x) => (x ?? '').toString().isNotEmpty).map((x) => x.toString()).toList();
              final price = (v['daily_price'] ?? '').toString();
              if (price.isNotEmpty) parts.add('$price KWD');
              final line = parts.join('  •  ');
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => showModalBottomSheet<void>(
                  context: c2,
                  isScrollControlled: true,
                  builder: (b) => _VehicleDetail(vehicle: v),
                ),
                child: Panel(
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: photos.isEmpty
                            ? Container(color: const Color(0x14000000), child: const Icon(Icons.local_shipping, color: kGreen))
                            : Image.network(
                                (photos.first['thumb'] ?? photos.first['url'] ?? '').toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((v['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (line.isNotEmpty) Text(line, style: const TextStyle(color: Colors.black54)),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            const Icon(Icons.photo_library_outlined, size: 15, color: Colors.black45),
                            const SizedBox(width: 4),
                            Text('${photos.length} ${c2.tr('photos_count')}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ]),
                        ),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black38),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

List<Json> _asList(dynamic v) => ((v as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class _VehicleForm extends StatefulWidget {
  const _VehicleForm();
  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final _name = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  final _cap = TextEditingController();
  final _price = TextEditingController();
  String? _svc;
  String? _type;
  final List<String> _photos = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final mine = ((s.user?['provider_services'] as List?) ?? []).map((e) => e.toString()).toList();
    final opts = s.services.where((x) => mine.contains(x['key'])).toList();
    if (opts.isNotEmpty) _svc = opts.first['key'] as String;
  }

  bool get _isRent => _svc == 'rental' || _svc == 'equipment';

  Future<void> _pickPhotos() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (r == null) return;
    setState(() {
      for (final f in r.files) {
        final path = f.path;
        if (path != null && _photos.length < 6 && !_photos.contains(path)) _photos.add(path);
      }
    });
  }

  Future<void> _save() async {
    final s = context.read<AppState>();
    if (_name.text.trim().isEmpty) return snack(context, context.tr('required'));
    final price = _price.text.trim().replaceAll(',', '.');
    if (_isRent && (_type == null || (double.tryParse(price) ?? 0) <= 0)) return snack(context, context.tr('required'));
    final nav = Navigator.of(context);
    final msgr = ScaffoldMessenger.of(context);
    final warn = context.tr('photos_failed');
    setState(() => _busy = true);
    try {
      final r = await s.api.addVehicle({
        'name': _name.text.trim(),
        'model': _model.text.trim(),
        'plate': _plate.text.trim(),
        'capacity': _cap.text.trim(),
        'service_key': _svc ?? '',
        if (_isRent) 'car_type': _type ?? '',
        if (_isRent) 'daily_price': price,
      });
      final id = (r['vehicle'] as Map)['id'] as int;
      if (_photos.isNotEmpty) {
        try {
          await s.api.uploadVehiclePhotos(id, _photos);
        } catch (_) {
          msgr.showSnackBar(SnackBar(content: Text(warn)));
        }
      }
      nav.pop(true);
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final mine = ((s.user?['provider_services'] as List?) ?? []).map((e) => e.toString()).toList();
    final opts = s.services.where((x) => mine.contains(x['key'])).toList();
    final types = _asList(s.config[_svc == 'equipment' ? 'equip_types' : 'car_types']);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('add_vehicle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(labelText: context.tr('vehicle_name'))),
          const SizedBox(height: 10),
          TextField(controller: _model, decoration: InputDecoration(labelText: context.tr('model'))),
          const SizedBox(height: 10),
          TextField(controller: _plate, decoration: InputDecoration(labelText: context.tr('plate'))),
          const SizedBox(height: 10),
          TextField(controller: _cap, decoration: InputDecoration(labelText: context.tr('capacity'))),
          if (opts.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _svc,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('service')),
              items: [for (final o in opts) DropdownMenuItem(value: o['key'] as String, child: Text(s.localized(o['name'])))],
              onChanged: (v) => setState(() {
                _svc = v;
                _type = null;
              }),
            ),
          ],
          if (_isRent) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _type,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('vehicle_type')),
              items: [for (final t in types) DropdownMenuItem(value: t['key'] as String, child: Text(s.localized(t['name'])))],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: context.tr('daily_price')),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _photos.length >= 6 ? null : _pickPhotos,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text('${context.tr('add_photos')}  (${_photos.length}/6)'),
          ),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(context.tr('photos_hint'), style: const TextStyle(fontSize: 12, color: Colors.grey))),
          if (_photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _photos)
                  Stack(clipBehavior: Clip.none, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(p), width: 64, height: 64, fit: BoxFit.cover)),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.remove(p)),
                        child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 13, color: Colors.white)),
                      ),
                    ),
                  ]),
              ]),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.tr('save')),
          ),
        ]),
      ),
    );
  }
}

class _VehicleDetail extends StatefulWidget {
  final Json vehicle;
  const _VehicleDetail({required this.vehicle});
  @override
  State<_VehicleDetail> createState() => _VehicleDetailState();
}

class _VehicleDetailState extends State<_VehicleDetail> {
  late Json _v;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _v = widget.vehicle;
  }

  List<Json> get _photos => _asList(_v['photos']);

  Future<void> _run(Future<Json> Function() f) async {
    final s = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final r = await f();
      if (!mounted) return;
      setState(() => _v = Map<String, dynamic>.from(r['vehicle'] as Map));
      s.bump();
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final room = 8 - _photos.length;
    if (room <= 0) return;
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (r == null) return;
    final paths = r.files.map((f) => f.path).whereType<String>().take(room).toList();
    if (paths.isEmpty || !mounted) return;
    final s = context.read<AppState>();
    await _run(() => s.api.uploadVehiclePhotos(_v['id'] as int, paths));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final photos = _photos;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text((_v['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          Text(context.tr('manage_photos') + '  (${photos.length}/8)', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(context.tr('no_photos'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)))
          else
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final p in photos)
                Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network((p['thumb'] ?? p['url'] ?? '').toString(), width: 96, height: 96, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 96, height: 96, child: Icon(Icons.broken_image_outlined))),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: _busy ? null : () => _run(() => s.api.removeVehiclePhoto(_v['id'] as int, p['id'] as int)),
                      child: const CircleAvatar(radius: 11, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)),
                    ),
                  ),
                ]),
            ]),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_busy || photos.length >= 8) ? null : _add,
            icon: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_a_photo_outlined),
            label: Text(context.tr('add_photos')),
          ),
        ]),
      ),
    );
  }
}

class ProviderRegisterScreen extends StatefulWidget {
  const ProviderRegisterScreen({super.key});
  @override
  State<ProviderRegisterScreen> createState() => _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController(); // person's full name, or company name
  final _civil = TextEditingController();
  final _crNo = TextEditingController();
  final _contact = TextEditingController();
  final _role = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _other = TextEditingController();
  final Set<String> _sel = {};
  final Map<String, String> _paths = {};
  final Map<String, String> _names = {};
  String _type = 'individual';
  String? _area;
  bool _busy = false;

  bool get _isCo => _type == 'company';

  Future<void> _pick(String field, {bool imageOnly = false}) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: imageOnly ? ['jpg', 'jpeg', 'png', 'webp'] : ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (r == null || r.files.isEmpty || r.files.single.path == null) return;
    final f = r.files.single;
    setState(() {
      _paths[field] = f.path!;
      _names[field] = f.name;
    });
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    if (_sel.isEmpty) return snack(context, context.tr('pick_service'));
    final mainField = _isCo ? 'cr_file' : 'id_file';
    if (_paths[mainField] == null) return snack(context, context.tr('files_needed'));
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    final fields = <String, String>{
      'provider_type': _type,
      'name': _name.text.trim(),
      'contact': _isCo ? _contact.text.trim() : _name.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'password': _pass.text,
      'services': _sel.join(','),
      'service_other': _other.text.trim(),
      if (_area != null) 'area': _area!,
      if (_isCo) 'cr_number': _crNo.text.trim(),
      if (_isCo) 'contact_role': _role.text.trim(),
      if (!_isCo) 'civil_id': _civil.text.trim(),
    };
    final files = <String, String>{
      mainField: _paths[mainField]!,
      if (!_isCo && _paths['license_file'] != null) 'license_file': _paths['license_file']!,
      if (_paths['logo'] != null) 'logo': _paths['logo']!,
    };
    setState(() => _busy = true);
    try {
      await s.providerRegister(fields, files);
      s.setTab(3);
      nav.pop(true);
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _filePick(String field, String label, {bool imageOnly = false}) {
    final name = _names[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: () => _pick(field, imageOnly: imageOnly),
        icon: Icon(name == null ? Icons.upload_file : Icons.check_circle, color: name == null ? null : Colors.green.shade700),
        label: Text(name ?? label, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    final areas = _asList(s.config['areas']);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('as_provider'))),
      body: SafeArea(
        child: Form(
          key: _key,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(context.tr('acct_type'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'individual', icon: const Icon(Icons.person_outline), label: Text(context.tr('individual'))),
                ButtonSegment(value: 'company', icon: const Icon(Icons.business_outlined), label: Text(context.tr('company_type'))),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 16),
            if (_isCo) ...[
              TextFormField(controller: _name, decoration: InputDecoration(labelText: context.tr('company')), validator: req),
              const SizedBox(height: 12),
              TextFormField(controller: _crNo, decoration: InputDecoration(labelText: context.tr('cr_number')), validator: req),
              const SizedBox(height: 12),
              TextFormField(controller: _contact, decoration: InputDecoration(labelText: context.tr('contact')), validator: req),
              const SizedBox(height: 12),
              TextFormField(controller: _role, decoration: InputDecoration(labelText: context.tr('contact_role'))),
            ] else ...[
              TextFormField(controller: _name, decoration: InputDecoration(labelText: context.tr('full_name')), validator: req),
              const SizedBox(height: 12),
              TextFormField(controller: _civil, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('civil_id')), validator: (v) => (v == null || v.trim().length < 6) ? context.tr('required') : null),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('phone')), validator: req),
            const SizedBox(height: 12),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: context.tr('email')), validator: req),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(labelText: context.tr('password')),
              validator: (v) => (v == null || v.length < 10) ? (s.lang == 'en' ? 'At least 10 characters' : '10 أحرف على الأقل') : null,
            ),
            if (areas.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _area,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.tr('area')),
                items: [for (final a in areas) DropdownMenuItem(value: a['key'] as String, child: Text(s.localized(a['name'])))],
                onChanged: (v) => setState(() => _area = v),
              ),
            ],
            const SizedBox(height: 16),
            Text(context.tr('services_offered'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final sv in s.services)
                FilterChip(
                  label: Text(s.localized(sv['name'])),
                  selected: _sel.contains(sv['key']),
                  onSelected: (v) => setState(() => v ? _sel.add(sv['key'] as String) : _sel.remove(sv['key'])),
                ),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _other, decoration: InputDecoration(labelText: context.tr('service_other'))),
            const SizedBox(height: 16),
            Text(context.tr('documents'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (_isCo) ...[
              _filePick('cr_file', context.tr('cr_file_req')),
              _filePick('logo', context.tr('logo_company'), imageOnly: true),
            ] else ...[
              _filePick('id_file', context.tr('id_file')),
              _filePick('license_file', context.tr('lic_file_opt')),
              _filePick('logo', context.tr('logo_person'), imageOnly: true),
            ],
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(context.tr('docs_hint'), style: const TextStyle(fontSize: 12, color: Colors.grey))),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.tr('register')),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (s.privacyUrl.isNotEmpty) TextButton(onPressed: () => openInApp(s.privacyUrl), child: Text(context.tr('privacy'))),
              if (s.termsUrl.isNotEmpty) TextButton(onPressed: () => openInApp(s.termsUrl), child: Text(context.tr('terms'))),
            ]),
          ]),
        ),
      ),
    );
  }
}
