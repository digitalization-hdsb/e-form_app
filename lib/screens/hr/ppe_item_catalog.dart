/// Mirrors the PPE_ITEMS / UNIFORM_ITEMS / OFFICE_ITEMS catalogs in
/// src/pages/PpeRequestForm.tsx, including per-size pricing.
class ItemSize {
  final String size;
  final double price;
  const ItemSize(this.size, this.price);
}

class CatalogItem {
  final String name;
  final List<ItemSize> sizes;
  final String unit;
  const CatalogItem(this.name, this.sizes, this.unit);

  double? unitPrice(String? selectedSize) {
    if (sizes.isEmpty) return null;
    if (selectedSize != null) {
      final match = sizes.where((s) => s.size == selectedSize);
      if (match.isNotEmpty) return match.first.price;
    }
    final allSame = sizes.every((s) => s.price == sizes.first.price);
    return allSame ? sizes.first.price : null;
  }
}

const _shoeSizesUk = [
  ItemSize('Size 3', 62.00), ItemSize('Size 4', 62.00), ItemSize('Size 5', 62.00),
  ItemSize('Size 6', 62.00), ItemSize('Size 7', 62.00), ItemSize('Size 8', 62.00),
  ItemSize('Size 9', 62.00), ItemSize('Size 10', 62.00), ItemSize('Size 11', 62.00),
  ItemSize('Size 12', 62.00), ItemSize('Size 13', 62.00),
];

const _clothingSizes = [
  ItemSize('XS', 0), ItemSize('S', 0), ItemSize('M', 0), ItemSize('L', 0),
  ItemSize('XL', 0), ItemSize('2XL', 0), ItemSize('3XL', 0), ItemSize('4XL', 0), ItemSize('5XL', 0),
];

List<ItemSize> _clothingPricedAt(double price) => _clothingSizes.map((s) => ItemSize(s.size, price)).toList();

const _pantsSizes = [
  ItemSize('26"', 40), ItemSize('28"', 40), ItemSize('30"', 40), ItemSize('32"', 40),
  ItemSize('34"', 40), ItemSize('36"', 40), ItemSize('38"', 40), ItemSize('40"', 40),
  ItemSize('42"', 40), ItemSize('44"', 40), ItemSize('46"', 40), ItemSize('48"', 40), ItemSize('50"', 40),
];

const _helmetSizes = [ItemSize('M', 11.00), ItemSize('L', 11.00)];

final List<CatalogItem> ppeItems = [
  const CatalogItem('3-ply Mask', [ItemSize('Free Size', 15.00)], 'Box'),
  const CatalogItem('Medical Apron', [ItemSize('Free Size', 25.00)], 'pcs'),
  const CatalogItem('Crane Vest', [ItemSize('Free Size', 0)], 'pcs'),
  const CatalogItem('Earplug', [ItemSize('Free Size', 1.10)], 'pair'),
  const CatalogItem('Forklift Vest', [ItemSize('Free Size', 0)], 'pcs'),
  const CatalogItem('Safety Goggles', [ItemSize('Free Size', 10.30)], 'pcs'),
  const CatalogItem('Safety Helmet', _helmetSizes, 'pcs'),
  const CatalogItem('N-95 Mask', [ItemSize('Free Size', 20.00)], 'pcs'),
  CatalogItem('Safety Boot', _shoeSizesUk, 'pair'),
  const CatalogItem('Safety Insert', [ItemSize('Free Size', 15.00)], 'pair'),
  CatalogItem('Safety Shoe', _shoeSizesUk, 'pair'),
]..sort((a, b) => a.name.compareTo(b.name));

final List<CatalogItem> uniformItems = [
  const CatalogItem('Cargo Pants', _pantsSizes, 'pcs'),
  CatalogItem('Company Shirt', _clothingPricedAt(16.00), 'pcs'),
  CatalogItem('Company Shirt (Long Sleeve)', _clothingPricedAt(17.00), 'pcs'),
  CatalogItem('Company T-Shirt (Long Sleeve)', _clothingPricedAt(23.00), 'pcs'),
  CatalogItem('Company T-Shirt (Short Sleeve)', _clothingPricedAt(20.00), 'pcs'),
]..sort((a, b) => a.name.compareTo(b.name));

final List<CatalogItem> officeItems = [
  const CatalogItem('A3 Paper', [ItemSize('80 gsm', 30.00)], 'ream'),
  const CatalogItem('A4 Paper', [ItemSize('70 gsm', 12.00), ItemSize('80 gsm', 15.00)], 'ream'),
  const CatalogItem('Ball Pen', [ItemSize('Black', 1.50), ItemSize('Blue', 1.50), ItemSize('Red', 1.50)], 'pcs'),
  const CatalogItem('Binder Clip', [ItemSize('Small', 3.00), ItemSize('Medium', 5.00), ItemSize('Large', 7.00)], 'box'),
  const CatalogItem('Cellophane Tape', [ItemSize('18 mm', 2.00)], 'roll'),
  const CatalogItem('Correction Fluid', [ItemSize('White', 4.50)], 'bottle'),
  const CatalogItem('Correction Tape', [ItemSize('5 mm', 5.00)], 'pcs'),
  const CatalogItem('Cutter Blade', [ItemSize('Large', 8.00)], 'pack'),
  const CatalogItem('Cutter Knife', [ItemSize('Large', 6.00)], 'pcs'),
  const CatalogItem('Document Tray', [ItemSize('Plastic', 15.00)], 'pcs'),
  const CatalogItem('Double-Sided Tape', [ItemSize('24 mm', 4.00)], 'roll'),
  const CatalogItem('Envelope', [ItemSize('C4', 0.50), ItemSize('DL', 0.30)], 'pcs'),
  const CatalogItem('Eraser', [ItemSize('Standard', 1.00)], 'pcs'),
  const CatalogItem('Glue Stick', [ItemSize('21 g', 3.50)], 'pcs'),
  const CatalogItem('Highlighter', [ItemSize('Yellow', 2.50), ItemSize('Green', 2.50), ItemSize('Pink', 2.50), ItemSize('Orange', 2.50)], 'pcs'),
  const CatalogItem('Lever Arch File', [ItemSize('2 inch', 8.00), ItemSize('3 inch', 10.00)], 'pcs'),
  const CatalogItem('Liquid Glue', [ItemSize('50 ml', 3.00)], 'bottle'),
  const CatalogItem('Masking Tape', [ItemSize('24 mm', 3.00)], 'roll'),
  const CatalogItem('Mechanical Pencil', [ItemSize('0.5 mm', 5.00)], 'pcs'),
  const CatalogItem('Notebook', [ItemSize('A4', 7.00), ItemSize('A5', 5.00)], 'pcs'),
  const CatalogItem('Paper Clip', [ItemSize('28 mm', 2.00)], 'box'),
  const CatalogItem('Pencil', [ItemSize('2B', 1.00)], 'pcs'),
  const CatalogItem('Pencil Lead', [ItemSize('0.5 mm', 2.50)], 'tube'),
  const CatalogItem('Permanent Marker', [ItemSize('Black', 3.00), ItemSize('Blue', 3.00), ItemSize('Red', 3.00)], 'pcs'),
  const CatalogItem('Ring File', [ItemSize('A4', 6.00)], 'pcs'),
  const CatalogItem('Rubber Band', [ItemSize('Small', 2.00), ItemSize('Large', 3.00)], 'pack'),
  const CatalogItem('Scissors', [ItemSize('Medium', 7.00)], 'pcs'),
  const CatalogItem('Sharpener', [ItemSize('Standard', 1.50)], 'pcs'),
  const CatalogItem('Stapler', [ItemSize('No.10', 12.00)], 'pcs'),
  const CatalogItem('Stapler Pin', [ItemSize('No.10', 2.00), ItemSize('3-1M', 3.00)], 'box'),
  const CatalogItem('Sticky Notes', [ItemSize('3" x 3"', 4.00)], 'pad'),
  const CatalogItem('Whiteboard Marker', [ItemSize('Black', 3.50), ItemSize('Blue', 3.50), ItemSize('Red', 3.50), ItemSize('Green', 3.50)], 'pcs'),
]..sort((a, b) => a.name.compareTo(b.name));
