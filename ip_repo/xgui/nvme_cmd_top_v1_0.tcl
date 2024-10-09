# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "BASE_ADDR_BAR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BASE_ADDR_BRAM" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BLOCK_SIZE_EXP" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PRPLIST_HEAP" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BASE_ADDR_XDMA" -parent ${Page_0}

  #Adding Page
  set page1 [ipgui::add_page $IPINST -name "page1" -display_name {Page 1}]
  set_property tooltip {Page 1} ${page1}
  ipgui::add_param $IPINST -name "ADDR_WIDTH" -parent ${page1}
  ipgui::add_param $IPINST -name "idController_ADDR" -parent ${page1}
  ipgui::add_param $IPINST -name "idNamespace_ADDR" -parent ${page1}
  ipgui::add_param $IPINST -name "IOCQ_ADDR" -parent ${page1}
  ipgui::add_param $IPINST -name "IOSQ_ADDR" -parent ${page1}
  ipgui::add_param $IPINST -name "ACQ_ADDR" -parent ${page1}
  ipgui::add_param $IPINST -name "ASQ_ADDR" -parent ${page1}

  ipgui::add_param $IPINST -name "Component_Name"

}

proc update_PARAM_VALUE.ACQ_ADDR { PARAM_VALUE.ACQ_ADDR } {
	# Procedure called to update ACQ_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ACQ_ADDR { PARAM_VALUE.ACQ_ADDR } {
	# Procedure called to validate ACQ_ADDR
	return true
}

proc update_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to update ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to validate ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.ASQ_ADDR { PARAM_VALUE.ASQ_ADDR } {
	# Procedure called to update ASQ_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ASQ_ADDR { PARAM_VALUE.ASQ_ADDR } {
	# Procedure called to validate ASQ_ADDR
	return true
}

proc update_PARAM_VALUE.BASE_ADDR_BAR { PARAM_VALUE.BASE_ADDR_BAR } {
	# Procedure called to update BASE_ADDR_BAR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BASE_ADDR_BAR { PARAM_VALUE.BASE_ADDR_BAR } {
	# Procedure called to validate BASE_ADDR_BAR
	return true
}

proc update_PARAM_VALUE.BASE_ADDR_BRAM { PARAM_VALUE.BASE_ADDR_BRAM } {
	# Procedure called to update BASE_ADDR_BRAM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BASE_ADDR_BRAM { PARAM_VALUE.BASE_ADDR_BRAM } {
	# Procedure called to validate BASE_ADDR_BRAM
	return true
}

proc update_PARAM_VALUE.BASE_ADDR_XDMA { PARAM_VALUE.BASE_ADDR_XDMA } {
	# Procedure called to update BASE_ADDR_XDMA when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BASE_ADDR_XDMA { PARAM_VALUE.BASE_ADDR_XDMA } {
	# Procedure called to validate BASE_ADDR_XDMA
	return true
}

proc update_PARAM_VALUE.BLOCK_SIZE_EXP { PARAM_VALUE.BLOCK_SIZE_EXP } {
	# Procedure called to update BLOCK_SIZE_EXP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BLOCK_SIZE_EXP { PARAM_VALUE.BLOCK_SIZE_EXP } {
	# Procedure called to validate BLOCK_SIZE_EXP
	return true
}

proc update_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to validate DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.IOCQ_ADDR { PARAM_VALUE.IOCQ_ADDR } {
	# Procedure called to update IOCQ_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IOCQ_ADDR { PARAM_VALUE.IOCQ_ADDR } {
	# Procedure called to validate IOCQ_ADDR
	return true
}

proc update_PARAM_VALUE.IOSQ_ADDR { PARAM_VALUE.IOSQ_ADDR } {
	# Procedure called to update IOSQ_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IOSQ_ADDR { PARAM_VALUE.IOSQ_ADDR } {
	# Procedure called to validate IOSQ_ADDR
	return true
}

proc update_PARAM_VALUE.IO_SIZE { PARAM_VALUE.IO_SIZE } {
	# Procedure called to update IO_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.IO_SIZE { PARAM_VALUE.IO_SIZE } {
	# Procedure called to validate IO_SIZE
	return true
}

proc update_PARAM_VALUE.PRPLIST_HEAP { PARAM_VALUE.PRPLIST_HEAP } {
	# Procedure called to update PRPLIST_HEAP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PRPLIST_HEAP { PARAM_VALUE.PRPLIST_HEAP } {
	# Procedure called to validate PRPLIST_HEAP
	return true
}

proc update_PARAM_VALUE.idController_ADDR { PARAM_VALUE.idController_ADDR } {
	# Procedure called to update idController_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.idController_ADDR { PARAM_VALUE.idController_ADDR } {
	# Procedure called to validate idController_ADDR
	return true
}

proc update_PARAM_VALUE.idNamespace_ADDR { PARAM_VALUE.idNamespace_ADDR } {
	# Procedure called to update idNamespace_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.idNamespace_ADDR { PARAM_VALUE.idNamespace_ADDR } {
	# Procedure called to validate idNamespace_ADDR
	return true
}


proc update_MODELPARAM_VALUE.BASE_ADDR_BRAM { MODELPARAM_VALUE.BASE_ADDR_BRAM PARAM_VALUE.BASE_ADDR_BRAM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BASE_ADDR_BRAM}] ${MODELPARAM_VALUE.BASE_ADDR_BRAM}
}

proc update_MODELPARAM_VALUE.BASE_ADDR_BAR { MODELPARAM_VALUE.BASE_ADDR_BAR PARAM_VALUE.BASE_ADDR_BAR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BASE_ADDR_BAR}] ${MODELPARAM_VALUE.BASE_ADDR_BAR}
}

proc update_MODELPARAM_VALUE.PRPLIST_HEAP { MODELPARAM_VALUE.PRPLIST_HEAP PARAM_VALUE.PRPLIST_HEAP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PRPLIST_HEAP}] ${MODELPARAM_VALUE.PRPLIST_HEAP}
}

proc update_MODELPARAM_VALUE.BLOCK_SIZE_EXP { MODELPARAM_VALUE.BLOCK_SIZE_EXP PARAM_VALUE.BLOCK_SIZE_EXP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BLOCK_SIZE_EXP}] ${MODELPARAM_VALUE.BLOCK_SIZE_EXP}
}

proc update_MODELPARAM_VALUE.ADDR_WIDTH { MODELPARAM_VALUE.ADDR_WIDTH PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ADDR_WIDTH}] ${MODELPARAM_VALUE.ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.DATA_WIDTH { MODELPARAM_VALUE.DATA_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WIDTH}] ${MODELPARAM_VALUE.DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.ASQ_ADDR { MODELPARAM_VALUE.ASQ_ADDR PARAM_VALUE.ASQ_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ASQ_ADDR}] ${MODELPARAM_VALUE.ASQ_ADDR}
}

proc update_MODELPARAM_VALUE.ACQ_ADDR { MODELPARAM_VALUE.ACQ_ADDR PARAM_VALUE.ACQ_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ACQ_ADDR}] ${MODELPARAM_VALUE.ACQ_ADDR}
}

proc update_MODELPARAM_VALUE.IO_SIZE { MODELPARAM_VALUE.IO_SIZE PARAM_VALUE.IO_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IO_SIZE}] ${MODELPARAM_VALUE.IO_SIZE}
}

proc update_MODELPARAM_VALUE.IOSQ_ADDR { MODELPARAM_VALUE.IOSQ_ADDR PARAM_VALUE.IOSQ_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IOSQ_ADDR}] ${MODELPARAM_VALUE.IOSQ_ADDR}
}

proc update_MODELPARAM_VALUE.IOCQ_ADDR { MODELPARAM_VALUE.IOCQ_ADDR PARAM_VALUE.IOCQ_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.IOCQ_ADDR}] ${MODELPARAM_VALUE.IOCQ_ADDR}
}

proc update_MODELPARAM_VALUE.idController_ADDR { MODELPARAM_VALUE.idController_ADDR PARAM_VALUE.idController_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.idController_ADDR}] ${MODELPARAM_VALUE.idController_ADDR}
}

proc update_MODELPARAM_VALUE.idNamespace_ADDR { MODELPARAM_VALUE.idNamespace_ADDR PARAM_VALUE.idNamespace_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.idNamespace_ADDR}] ${MODELPARAM_VALUE.idNamespace_ADDR}
}

proc update_MODELPARAM_VALUE.BASE_ADDR_XDMA { MODELPARAM_VALUE.BASE_ADDR_XDMA PARAM_VALUE.BASE_ADDR_XDMA } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BASE_ADDR_XDMA}] ${MODELPARAM_VALUE.BASE_ADDR_XDMA}
}

