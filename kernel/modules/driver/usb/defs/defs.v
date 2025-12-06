module defs

pub const desc_device = 1
pub const desc_configuration = 2
pub const desc_string = 3
pub const desc_interface = 4
pub const desc_endpoint = 5

pub const desc_hid = 0x21
pub const desc_report = 0x22

pub const req_get_status = 0
pub const req_clear_feature = 1
pub const req_set_feature = 3
pub const req_set_address = 5
pub const req_get_descriptor = 6
pub const req_set_descriptor = 7
pub const req_get_configuration = 8
pub const req_set_configuration = 9

pub const req_dir_in = 0x80
pub const req_dir_out = 0x00
pub const req_type_standard = 0x00
pub const req_type_class = 0x20
pub const req_type_vendor = 0x40
pub const req_rec_device = 0x00
pub const req_rec_interface = 0x01
pub const req_rec_endpoint = 0x02

pub const class_per_interface = 0x00
pub const class_audio = 0x01
pub const class_comm = 0x02
pub const class_hid = 0x03
pub const class_physical = 0x05
pub const class_image = 0x06
pub const class_printer = 0x07
pub const class_mass_storage = 0x08
pub const class_hub = 0x09
pub const class_data = 0x0a
pub const class_smart_card = 0x0b
pub const class_video = 0x0e
pub const class_healthcare = 0x0f
pub const class_diagnostic = 0xdc
pub const class_wireless = 0xe0
pub const class_misc = 0xef
pub const class_vendor_spec = 0xff

pub const ep_type_control = 0
pub const ep_type_iso = 1
pub const ep_type_bulk = 2
pub const ep_type_int = 3

pub const req_get_report = 0x01
pub const req_get_idle = 0x02
pub const req_get_protocol = 0x03
pub const req_set_report = 0x09
pub const req_set_idle = 0x0a
pub const req_set_protocol = 0x0b

pub const proto_boot = 0
pub const proto_report = 1
