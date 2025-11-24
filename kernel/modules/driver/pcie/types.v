module pcie

enum PciDeviceType {
	unknown
	ide_controller
	sata_controller
	nvme_controller
	ethernet_controller
	vga_compatible
	audio_device
	host_bridge
	isa_bridge
	pci_pci_bridge
	usb_controller
	smbus_controller
	bluetooth_controller
}

fn (dt PciDeviceType) name() &char {
	return match dt {
		.ide_controller { c'IDE Controller' }
		.sata_controller { c'SATA Controller' }
		.nvme_controller { c'NVMe Controller' }
		.ethernet_controller { c'Ethernet Controller' }
		.vga_compatible { c'VGA Compatible' }
		.audio_device { c'Audio Device' }
		.host_bridge { c'Host Bridge' }
		.isa_bridge { c'ISA Bridge' }
		.pci_pci_bridge { c'PCI-PCI Bridge' }
		.usb_controller { c'USB Controller' }
		.smbus_controller { c'SMBus Controller' }
		.bluetooth_controller { c'Bluetooth Controller' }
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
		0x03_00 { .vga_compatible }
		0x04_03 { .audio_device }
		0x06_00 { .host_bridge }
		0x06_01 { .isa_bridge }
		0x06_04 { .pci_pci_bridge }
		0x06_09 { .pci_pci_bridge }
		0x0c_03 { .usb_controller }
		0x0c_05 { .smbus_controller }
		0x0d_11 { .bluetooth_controller }
		else { .unknown }
	}
}
