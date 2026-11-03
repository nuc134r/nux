import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart' show parseNetworkId;

import '../../../l10n/l10n.dart';
import '../data/zerotier_service.dart';

/// Picks a ZeroTier network: one already joined, or a new 16-digit id.
class ZeroTierNetworkField extends ConsumerStatefulWidget {
  const ZeroTierNetworkField({super.key, required this.initial, required this.onChanged, this.label});

  final String? initial;
  final ValueChanged<String?> onChanged;
  final String? label;

  @override
  ConsumerState<ZeroTierNetworkField> createState() => _ZeroTierNetworkFieldState();
}

class _ZeroTierNetworkFieldState extends ConsumerState<ZeroTierNetworkField> {
  late final _text = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final service = ref.watch(zeroTierServiceProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final known = service.networks;
        return Autocomplete<String>(
          initialValue: TextEditingValue(text: widget.initial ?? ''),
          optionsBuilder: (v) => known.where((n) => n.contains(v.text.toLowerCase())),
          displayStringForOption: (n) => n,
          onSelected: widget.onChanged,
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final n in options)
                      ListTile(
                        title: Text(n),
                        subtitle: service.network(n)?.name == null ? null : Text(service.network(n)!.name!),
                        onTap: () => onSelected(n),
                      ),
                  ],
                ),
              ),
            ),
          ),
          fieldViewBuilder: (context, controller, focus, onSubmit) => TextFormField(
            controller: controller,
            focusNode: focus,
            autocorrect: false,
            maxLength: 16,
            decoration: InputDecoration(labelText: widget.label ?? l10n.zerotierNetwork, hintText: '8056c2e21c000001', counterText: ''),
            onChanged: (v) => widget.onChanged(parseNetworkId(v) == null ? null : v.trim().toLowerCase()),
            validator: (v) => parseNetworkId(v ?? '') == null ? l10n.invalidNetworkId : null,
          ),
        );
      },
    );
  }
}
