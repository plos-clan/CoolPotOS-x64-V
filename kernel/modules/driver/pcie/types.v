module pcie

pub enum PciDeviceType {
	unknown
	ide_controller
	sata_controller
	nvme_controller
	ethernet_controller
	network_controller
	vga_compatible
	audio_device
	host_bridge
	isa_bridge
	pci_pci_bridge
	usb_controller
	smbus_controller
	bluetooth_controller
	serial_controller
	memory_controller
	iommu
	system_peripheral
}

fn (dt PciDeviceType) name() &char {
	return match dt {
		.ide_controller { c'IDE Controller' }
		.sata_controller { c'SATA Controller' }
		.nvme_controller { c'NVMe Controller' }
		.ethernet_controller { c'Ethernet Controller' }
		.network_controller { c'Network Controller' }
		.vga_compatible { c'VGA Compatible Display' }
		.audio_device { c'Audio Device' }
		.host_bridge { c'Host Bridge' }
		.isa_bridge { c'ISA Bridge' }
		.pci_pci_bridge { c'PCI-PCI Bridge' }
		.usb_controller { c'USB Controller' }
		.smbus_controller { c'SMBus Controller' }
		.bluetooth_controller { c'Bluetooth Controller' }
		.serial_controller { c'Serial Port Controller' }
		.memory_controller { c'Memory Controller' }
		.iommu { c'IOMMU' }
		.system_peripheral { c'System Peripheral' }
		.unknown { c'Unknown Device' }
	}
}

fn PciDeviceType.parse(class u8, sub u8) PciDeviceType {
	id := u16(class) << 8 | u16(sub)

	return match id {
		0x01_01 { .ide_controller }
		0x01_06 { .sata_controller }
		0x01_08 { .nvme_controller }
		0x02_00 { .ethernet_controller }
		0x02_80 { .network_controller }
		0x03_00 { .vga_compatible }
		0x04_03 { .audio_device }
		0x05_00 { .memory_controller }
		0x06_00 { .host_bridge }
		0x06_01 { .isa_bridge }
		0x06_04 { .pci_pci_bridge }
		0x06_09 { .pci_pci_bridge }
		0x07_00 { .serial_controller }
		0x08_06 { .iommu }
		0x08_80 { .system_peripheral }
		0x0c_03 { .usb_controller }
		0x0c_05 { .smbus_controller }
		0x0d_11 { .bluetooth_controller }
		else { .unknown }
	}
}
