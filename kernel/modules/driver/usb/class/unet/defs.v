module unet

pub const req_send_encapsulated_command = 0x00
pub const req_get_encapsulated_response = 0x01

pub const rndis_packet_msg = u32(0x00000001)
pub const rndis_initialize_msg = u32(0x00000002)
pub const rndis_halt_msg = u32(0x00000003)
pub const rndis_query_msg = u32(0x00000004)
pub const rndis_set_msg = u32(0x00000005)
pub const rndis_reset_msg = u32(0x00000006)
pub const rndis_indicate_status = u32(0x00000007)
pub const rndis_keepalive_msg = u32(0x00000008)

pub const rndis_initialize_cmplt = u32(0x80000002)
pub const rndis_query_cmplt = u32(0x80000004)
pub const rndis_set_cmplt = u32(0x80000005)
pub const rndis_reset_cmplt = u32(0x80000006)
pub const rndis_keepalive_cmplt = u32(0x80000008)

pub const oid_gen_supported_list = u32(0x00010101)
pub const oid_gen_hardware_status = u32(0x00010102)
pub const oid_gen_media_supported = u32(0x00010103)
pub const oid_gen_media_in_use = u32(0x00010104)
pub const oid_gen_max_frame_size = u32(0x00010106)
pub const oid_gen_link_speed = u32(0x00010107)
pub const oid_gen_transmit_block_size = u32(0x0001010a)
pub const oid_gen_receive_block_size = u32(0x0001010b)
pub const oid_gen_vendor_id = u32(0x0001010c)
pub const oid_gen_vendor_description = u32(0x0001010d)
pub const oid_gen_current_packet_filter = u32(0x0001010e)
pub const oid_gen_max_total_size = u32(0x00010111)
pub const oid_gen_media_connect_status = u32(0x00010114)
pub const oid_802_3_permanent_address = u32(0x01010101)
pub const oid_802_3_current_address = u32(0x01010102)
pub const oid_802_3_multicast_list = u32(0x01010103)
pub const oid_802_3_max_list_size = u32(0x01010104)

pub const rndis_packet_type_directed = u32(0x00000001)
pub const rndis_packet_type_multicast = u32(0x00000002)
pub const rndis_packet_type_all_multicast = u32(0x00000004)
pub const rndis_packet_type_broadcast = u32(0x00000008)
pub const rndis_packet_type_promiscuous = u32(0x00000020)

pub const rndis_status_success = u32(0x00000000)
pub const rndis_status_failure = u32(0xc0000001)

@[packed]
pub struct RndisMsgHeader {
pub mut:
	msg_type u32
	msg_len  u32
}

@[packed]
pub struct RndisInitMsg {
pub mut:
	header        RndisMsgHeader
	request_id    u32
	major_version u32
	minor_version u32
	max_xfer_size u32
}

@[packed]
pub struct RndisInitCmplt {
pub mut:
	header               RndisMsgHeader
	request_id           u32
	status               u32
	major_version        u32
	minor_version        u32
	device_flags         u32
	medium               u32
	max_packets_per_xfer u32
	max_xfer_size        u32
	packet_align_factor  u32
	reserved             [2]u32
}

@[packed]
pub struct RndisSetMsg {
pub mut:
	header          RndisMsgHeader
	request_id      u32
	oid             u32
	info_buf_len    u32
	info_buf_offset u32
	reserved        u32
}

@[packed]
pub struct RndisSetCmplt {
pub mut:
	header     RndisMsgHeader
	request_id u32
	status     u32
}

@[packed]
pub struct RndisQueryMsg {
pub mut:
	header          RndisMsgHeader
	request_id      u32
	oid             u32
	info_buf_len    u32
	info_buf_offset u32
	reserved        u32
}

@[packed]
pub struct RndisQueryCmplt {
pub mut:
	header          RndisMsgHeader
	request_id      u32
	status          u32
	info_buf_len    u32
	info_buf_offset u32
}

@[packed]
pub struct RndisPacketMsg {
pub mut:
	header                 RndisMsgHeader
	data_offset            u32
	data_len               u32
	oob_data_offset        u32
	oob_data_len           u32
	num_oob_data_elements  u32
	per_packet_info_offset u32
	per_packet_info_len    u32
	vc_handle              u32
	reserved               u32
}
