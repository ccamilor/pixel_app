import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../inventory/data/repositories/inventory_repository.dart';
import '../../../inventory/domain/entities/material_entity.dart';
import '../../data/repositories/client_repository.dart';
import '../../domain/entities/client_entity.dart';

/// Vista unificada de Clientes (con datos de moto y WhatsApp) e Inventario (con alertas min_stock).
class ClientsInventoryPage extends ConsumerStatefulWidget {
  const ClientsInventoryPage({super.key});

  @override
  ConsumerState<ClientsInventoryPage> createState() =>
      _ClientsInventoryPageState();
}

class _ClientsInventoryPageState extends ConsumerState<ClientsInventoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clientes e Inventario',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentCyan,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Clientes'),
            Tab(icon: Icon(Icons.layers_outlined), text: 'Materiales / Stock'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ClientsTab(
            searchQuery: _searchQuery,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            onEdit: (client) => _showClientDialog(context, client: client),
          ),
          _InventoryTab(
            onEdit: (material) => _showMaterialDialog(context, material: material),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showClientDialog(context);
          } else {
            _showMaterialDialog(context);
          }
        },
        icon: const Icon(Icons.add),
        label: AnimatedBuilder(
          animation: _tabController,
          builder: (_, _) => Text(
            _tabController.index == 0 ? 'Nuevo Cliente' : 'Nuevo Material',
          ),
        ),
      ),
    );
  }

  Future<void> _showClientDialog(
    BuildContext context, {
    ClientEntity? client,
  }) async {
    final nameCtrl = TextEditingController(text: client?.name ?? '');
    final phoneCtrl = TextEditingController(text: client?.phone ?? '');
    final docCtrl = TextEditingController(text: client?.documentId ?? '');
    final vehicleCtrl = TextEditingController(text: client?.vehicleInfo ?? '');
    final notesCtrl = TextEditingController(text: client?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(client == null ? 'Nuevo Cliente' : 'Editar Cliente'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre / Razón social *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp (Ej. 3001234567)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: vehicleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Moto / Vehículo (Ej. Pulsar NS200 Negra)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: docCtrl,
                  decoration: const InputDecoration(labelText: 'Cédula / NIT (opcional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notas / Preferencias'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await ref.read(clientRepositoryProvider).saveClient(
                    id: client?.id,
                    name: nameCtrl.text,
                    phone: phoneCtrl.text,
                    documentId: docCtrl.text,
                    vehicleInfo: vehicleCtrl.text,
                    notes: notesCtrl.text,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMaterialDialog(
    BuildContext context, {
    MaterialEntity? material,
  }) async {
    final nameCtrl = TextEditingController(text: material?.name ?? '');
    final costCtrl = TextEditingController(
      text: material != null ? material.unitCost.toStringAsFixed(0) : '',
    );
    final saleCtrl = TextEditingController(
      text:
          material != null ? material.suggestedSalePrice.toStringAsFixed(0) : '',
    );
    final wasteCtrl = TextEditingController(
      text: (material?.defaultWastePercentage ?? 15.0).toStringAsFixed(0),
    );
    final stockCtrl = TextEditingController(
      text: (material?.stock ?? 0).toStringAsFixed(1),
    );
    final minStockCtrl = TextEditingController(
      text: (material?.minStock ?? 5).toStringAsFixed(1),
    );
    var selectedUnit = material?.unit ?? MaterialUnit.m2;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(material == null ? 'Nuevo Material' : 'Editar Material'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Material (Ej. Vinilo Reflectivo 3M) *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MaterialUnit>(
                    initialValue: selectedUnit,
                    decoration: const InputDecoration(labelText: 'Unidad de medida'),
                    items: MaterialUnit.values
                        .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedUnit = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Costo base'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: saleCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Precio venta'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock actual'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: minStockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock mínimo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: wasteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Merma por defecto (%)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await ref.read(inventoryRepositoryProvider).saveMaterial(
                      id: material?.id,
                      name: nameCtrl.text,
                      unit: selectedUnit,
                      unitCost: double.tryParse(costCtrl.text) ?? 0,
                      suggestedSalePrice: double.tryParse(saleCtrl.text) ?? 0,
                      defaultWastePercentage: double.tryParse(wasteCtrl.text) ?? 15,
                      stock: double.tryParse(stockCtrl.text) ?? 0,
                      minStock: double.tryParse(minStockCtrl.text) ?? 0,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientsTab extends ConsumerWidget {
  const _ClientsTab({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onEdit,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ClientEntity> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsStreamProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, teléfono o moto...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (clients) {
              final q = searchQuery.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? clients
                  : clients.where((c) {
                      return c.name.toLowerCase().contains(q) ||
                          c.phone.toLowerCase().contains(q) ||
                          (c.vehicleInfo?.toLowerCase().contains(q) ?? false);
                    }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'Aún no hay clientes registrados.\nPulsa "+ Nuevo Cliente" para empezar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final client = filtered[index];
                  return Card(
                    child: ListTile(
                      onTap: () => onEdit(client),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryDeepBlue,
                        child: Text(
                          client.name.isNotEmpty
                              ? client.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: AppColors.accentCyan),
                        ),
                      ),
                      title: Text(
                        client.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (client.vehicleInfo != null)
                            Text(
                              'Moto: ${client.vehicleInfo}',
                              style: const TextStyle(color: AppColors.accentCyan),
                            ),
                          if (client.phone.isNotEmpty)
                            Text(
                              client.phone,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (client.phone.isNotEmpty)
                            IconButton(
                              tooltip: 'Abrir WhatsApp',
                              icon: const Icon(
                                Icons.chat_rounded,
                                color: AppColors.success,
                              ),
                              onPressed: () => WhatsAppLauncher.openChat(
                                phone: client.phone,
                                message: 'Hola ${client.name}, te escribo desde Pixel.',
                              ),
                            ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => ref
                                .read(clientRepositoryProvider)
                                .deleteClient(client.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab({required this.onEdit});

  final ValueChanged<MaterialEntity> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialsStreamProvider);

    return materialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (materials) {
        if (materials.isEmpty) {
          return const Center(
            child: Text(
              'Sin materiales en inventario.\nAgrega tus vinilos, laminados y papel transfer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: materials.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = materials[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: item.isLowStock ? AppColors.warning : AppColors.border,
                  width: item.isLowStock ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                onTap: () => onEdit(item),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (item.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'STOCK BAJO',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Stock: ${item.stock.toStringAsFixed(1)} ${item.unit.label} (mín: ${item.minStock.toStringAsFixed(1)})',
                        style: TextStyle(
                          color: item.isLowStock
                              ? AppColors.warning
                              : AppColors.accentCyan,
                        ),
                      ),
                      Text(
                        'Costo: ${AppFormatters.currency(item.unitCost)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        'Venta: ${AppFormatters.currency(item.suggestedSalePrice)}',
                        style: const TextStyle(color: AppColors.success),
                      ),
                    ],
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Reponer +5',
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.accentCyan,
                  ),
                  onPressed: () => ref
                      .read(inventoryRepositoryProvider)
                      .adjustStock(item.id, 5),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
