import PGTypes::*;

interface SoCMap;
    (* always_ready *) method  Fabric_Addr  m_plic_addr_base;
    (* always_ready *) method  Fabric_Addr  m_plic_addr_size;
    (* always_ready *) method  Fabric_Addr  m_plic_addr_lim;

    (* always_ready *) method  Fabric_Addr  m_near_mem_io_addr_base;
    (* always_ready *) method  Fabric_Addr  m_near_mem_io_addr_size;
    (* always_ready *) method  Fabric_Addr  m_near_mem_io_addr_lim;

    (* always_ready *) method  Fabric_Addr  m_flash_mem_addr_base;
    (* always_ready *) method  Fabric_Addr  m_flash_mem_addr_size;
    (* always_ready *) method  Fabric_Addr  m_flash_mem_addr_lim;

    (* always_ready *) method  Fabric_Addr  uart0Base;
    (* always_ready *) method  Fabric_Addr  uart0Size;

    (* always_ready *) method  Fabric_Addr  m_gpio_0_addr_base;
    (* always_ready *) method  Fabric_Addr  m_gpio_0_addr_size;
    (* always_ready *) method  Fabric_Addr  m_gpio_0_addr_lim;

    (* always_ready *) method  Fabric_Addr  m_boot_rom_addr_base;
    (* always_ready *) method  Fabric_Addr  m_boot_rom_addr_size;
    (* always_ready *) method  Fabric_Addr  m_boot_rom_addr_lim;

    (* always_ready *) method  Fabric_Addr  m_ddr4_0_uncached_addr_base;
    (* always_ready *) method  Fabric_Addr  m_ddr4_0_uncached_addr_size;
    (* always_ready *) method  Fabric_Addr  m_ddr4_0_uncached_addr_lim;

    (* always_ready *) method  Fabric_Addr  m_ddr4_0_cached_addr_base;
    (* always_ready *) method  Fabric_Addr  m_ddr4_0_cached_addr_size;
    (* always_ready *) method  Fabric_Addr  m_ddr4_0_cached_addr_lim;
endinterface
