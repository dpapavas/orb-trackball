#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include <avr/power.h>
#include <avr/wdt.h>

#include <LUFA/Drivers/USB/USB.h>
#include <LUFA/Platform/Platform.h>

#include "config.h"

#ifdef ENABLE_CDC
#define CDC_NOTIFICATION_EPADDR (ENDPOINT_DIR_IN | 2)
#define CDC_TX_EPADDR (ENDPOINT_DIR_IN | 3)
#define CDC_RX_EPADDR (ENDPOINT_DIR_OUT | 4)
#define CDC_NOTIFICATION_EPSIZE 8
#define CDC_TXRX_EPSIZE 16
#endif

#define MOUSE_EPADDR (ENDPOINT_DIR_IN | 1)
#define MOUSE_EPSIZE 8

enum
{
#ifdef ENABLE_CDC
    INTERFACE_ID_CDC_CCI,
    INTERFACE_ID_CDC_DCI,
#endif

    INTERFACE_ID_Mouse,
};

enum
{
    STRING_ID_Language,
    STRING_ID_Manufacturer,
    STRING_ID_Product,
};

typedef struct
{
    USB_Descriptor_Configuration_Header_t Config;

#ifdef ENABLE_CDC
    /* CDC Control Interface */

    USB_Descriptor_Interface_Association_t CDC_IAD;
    USB_Descriptor_Interface_t CDC_CCI_Interface;
    USB_CDC_Descriptor_FunctionalHeader_t CDC_Functional_Header;
    USB_CDC_Descriptor_FunctionalACM_t CDC_Functional_ACM;
    USB_CDC_Descriptor_FunctionalUnion_t CDC_Functional_Union;
    USB_Descriptor_Endpoint_t CDC_NotificationEndpoint;

    /* CDC Data Interface */

    USB_Descriptor_Interface_t CDC_DCI_Interface;
    USB_Descriptor_Endpoint_t CDC_DataOutEndpoint;
    USB_Descriptor_Endpoint_t CDC_DataInEndpoint;
#endif

    /* Mouse HID Interface */

    USB_Descriptor_Interface_t HID_Interface;
    USB_HID_Descriptor_HID_t HID_MouseHID;
    USB_Descriptor_Endpoint_t HID_ReportINEndpoint;
} USB_Descriptor_Configuration_t;

typedef struct {
    uint8_t buttons;
    int16_t axes[4];
} MouseReport_Data_t;

typedef struct {
    uint8_t multiplier;
} FeatureReport_Data_t;

void EVENT_USB_Device_Connect(void);
void EVENT_USB_Device_Disconnect(void);
void EVENT_USB_Device_ConfigurationChanged(void);
void EVENT_USB_Device_ControlRequest(void);
void EVENT_USB_Device_StartOfFrame(void);

bool CALLBACK_HID_Device_CreateHIDReport(
    USB_ClassInfo_HID_Device_t *const HIDInterfaceInfo,
    uint8_t *const ReportID,
    const uint8_t ReportType,
    void* ReportData,
    uint16_t *const ReportSize);

void CALLBACK_HID_Device_ProcessHIDReport(
    USB_ClassInfo_HID_Device_t *const HIDInterfaceInfo,
    const uint8_t ReportID,
    const uint8_t ReportType,
    const void* ReportData,
    const uint16_t ReportSize);

uint16_t CALLBACK_USB_GetDescriptor(const uint16_t wValue,
                                    const uint16_t wIndex,
                                    const void** const DescriptorAddress)
    ATTR_WARN_UNUSED_RESULT ATTR_NON_NULL_PTR_ARG(3);

#define BUTTON_COUNT sizeof((uint8_t[]){BUTTONS})

const USB_Descriptor_HIDReport_Datatype_t PROGMEM MouseReport[] = {
    HID_RI_USAGE_PAGE(8, 0x01), /* Generic Desktop */
    HID_RI_USAGE(8, 0x02), /* Mouse */
    HID_RI_COLLECTION(8, 0x01), /* Application */
    HID_RI_USAGE(8, 0x01), /* Pointer */
    HID_RI_COLLECTION(8, 0x00), /* Physical */
    HID_RI_USAGE_PAGE(8, 0x09), /* Button */
    HID_RI_USAGE_MINIMUM(8, 0x01),
    HID_RI_USAGE_MAXIMUM(8, BUTTON_COUNT),
    HID_RI_LOGICAL_MINIMUM(8, 0x00),
    HID_RI_LOGICAL_MAXIMUM(8, 0x01),
    HID_RI_REPORT_COUNT(8, BUTTON_COUNT),
    HID_RI_REPORT_SIZE(8, 0x01),
    HID_RI_INPUT(8, HID_IOF_DATA | HID_IOF_VARIABLE | HID_IOF_ABSOLUTE),
    HID_RI_REPORT_COUNT(8, 0x01),
    HID_RI_REPORT_SIZE(8, 8 - (BUTTON_COUNT % 8)),
    HID_RI_INPUT(8, HID_IOF_CONSTANT),

    HID_RI_USAGE_PAGE(8, 0x01), /* Generic Desktop */
    HID_RI_USAGE(8, 0x30), /* Usage X */
    HID_RI_USAGE(8, 0x31), /* Usage Y */
    HID_RI_LOGICAL_MINIMUM(16, -32768),
    HID_RI_LOGICAL_MAXIMUM(16, 32767),
    HID_RI_PHYSICAL_MINIMUM(8, -1),
    HID_RI_PHYSICAL_MAXIMUM(8, 1),
    HID_RI_REPORT_COUNT(8, 0x02),
    HID_RI_REPORT_SIZE(8, 16),
    HID_RI_INPUT(8, HID_IOF_DATA | HID_IOF_VARIABLE | HID_IOF_RELATIVE),

    HID_RI_COLLECTION(8, 0x02), /* Logical */
    HID_RI_USAGE(8, 0x48), /* Resolution Multiplier */
    HID_RI_LOGICAL_MINIMUM(8, 0x00),
    HID_RI_LOGICAL_MAXIMUM(8, 0x01),
    HID_RI_PHYSICAL_MINIMUM(8, 0x01),
    HID_RI_PHYSICAL_MAXIMUM(8, 120),
    HID_RI_REPORT_COUNT(8, 0x01),
    HID_RI_REPORT_SIZE(8, 0x02),
    HID_RI_FEATURE(8, HID_IOF_DATA | HID_IOF_VARIABLE | HID_IOF_ABSOLUTE),

    HID_RI_USAGE_PAGE(8, 0x0c), /* Consumer devices */
    HID_RI_USAGE(16, 0x0238), /* AC pan */
    HID_RI_LOGICAL_MINIMUM(16, -32768),
    HID_RI_LOGICAL_MAXIMUM(16, 32767),
    HID_RI_PHYSICAL_MINIMUM(8, 0),
    HID_RI_PHYSICAL_MAXIMUM(8, 0),
    HID_RI_REPORT_SIZE(8, 16),
    HID_RI_INPUT(8, HID_IOF_DATA | HID_IOF_VARIABLE | HID_IOF_RELATIVE),

    HID_RI_USAGE_PAGE(8, 0x01), /* Generic Desktop */
    HID_RI_USAGE(8, 0x38), /* Wheel */
    HID_RI_LOGICAL_MINIMUM(16, -32768),
    HID_RI_LOGICAL_MAXIMUM(16, 32767),
    HID_RI_PHYSICAL_MINIMUM(8, 0),
    HID_RI_PHYSICAL_MAXIMUM(8, 0),
    HID_RI_REPORT_SIZE(8, 16),
    HID_RI_INPUT(8, HID_IOF_DATA | HID_IOF_VARIABLE | HID_IOF_RELATIVE),
    HID_RI_END_COLLECTION(0),

    HID_RI_REPORT_COUNT(8, 0x01),
    HID_RI_REPORT_SIZE(8, 0x06),
    HID_RI_FEATURE(8, HID_IOF_CONSTANT | HID_IOF_VARIABLE | HID_IOF_ABSOLUTE),

    HID_RI_END_COLLECTION(0),
    HID_RI_END_COLLECTION(0)
};

const USB_Descriptor_Device_t PROGMEM DeviceDescriptor = {
    .Header = {.Size = sizeof(USB_Descriptor_Device_t), .Type = DTYPE_Device},

    .USBSpecification = VERSION_BCD(1,1,0),
#ifdef ENABLE_CDC
    .Class = USB_CSCP_IADDeviceClass,
    .SubClass = USB_CSCP_IADDeviceSubclass,
    .Protocol = USB_CSCP_IADDeviceProtocol,
#else
    .Class = USB_CSCP_NoDeviceClass,
    .SubClass = USB_CSCP_NoDeviceSubclass,
    .Protocol = USB_CSCP_NoDeviceProtocol,
#endif

    .Endpoint0Size = FIXED_CONTROL_ENDPOINT_SIZE,

    .VendorID = VENDOR_ID,
    .ProductID = PRODUCT_ID,
    .ReleaseNumber = VERSION_BCD(0,0,1),

    .ManufacturerStrIndex = STRING_ID_Manufacturer,
    .ProductStrIndex = STRING_ID_Product,
    .SerialNumStrIndex = USE_INTERNAL_SERIAL,

    .NumberOfConfigurations = FIXED_NUM_CONFIGURATIONS
};

const USB_Descriptor_Configuration_t PROGMEM ConfigurationDescriptor = {
    .Config =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Configuration_Header_t),
            .Type = DTYPE_Configuration},

        .TotalConfigurationSize = sizeof(USB_Descriptor_Configuration_t),
#ifdef ENABLE_CDC
        .TotalInterfaces = 3,
#else
        .TotalInterfaces = 1,
#endif

        .ConfigurationNumber = 1,
        .ConfigurationStrIndex = NO_DESCRIPTOR,

        .ConfigAttributes = (USB_CONFIG_ATTR_RESERVED
                             | USB_CONFIG_ATTR_SELFPOWERED),

        .MaxPowerConsumption = USB_CONFIG_POWER_MA(100)
    },

#ifdef ENABLE_CDC
    .CDC_IAD =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Interface_Association_t),
            .Type = DTYPE_InterfaceAssociation},

        .FirstInterfaceIndex = INTERFACE_ID_CDC_CCI,
        .TotalInterfaces = 2,

        .Class = CDC_CSCP_CDCClass,
        .SubClass = CDC_CSCP_ACMSubclass,
        .Protocol = CDC_CSCP_ATCommandProtocol,

        .IADStrIndex = NO_DESCRIPTOR
    },

    .CDC_CCI_Interface =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Interface_t),
            .Type = DTYPE_Interface},

        .InterfaceNumber = INTERFACE_ID_CDC_CCI,
        .AlternateSetting = 0,

        .TotalEndpoints = 1,

        .Class = CDC_CSCP_CDCClass,
        .SubClass = CDC_CSCP_ACMSubclass,
        .Protocol = CDC_CSCP_ATCommandProtocol,

        .InterfaceStrIndex = NO_DESCRIPTOR
    },

    .CDC_Functional_Header =
    {
        .Header = {
            .Size = sizeof(USB_CDC_Descriptor_FunctionalHeader_t),
            .Type = CDC_DTYPE_CSInterface},

        .Subtype = CDC_DSUBTYPE_CSInterface_Header,
        .CDCSpecification = VERSION_BCD(1,1,0),
    },

    .CDC_Functional_ACM =
    {
        .Header = {
            .Size = sizeof(USB_CDC_Descriptor_FunctionalACM_t),
            .Type = CDC_DTYPE_CSInterface},

        .Subtype = CDC_DSUBTYPE_CSInterface_ACM,
        .Capabilities = 0x06,
    },

    .CDC_Functional_Union =
    {
        .Header = {
            .Size = sizeof(USB_CDC_Descriptor_FunctionalUnion_t),
            .Type = CDC_DTYPE_CSInterface},

        .Subtype = CDC_DSUBTYPE_CSInterface_Union,

        .MasterInterfaceNumber = INTERFACE_ID_CDC_CCI,
        .SlaveInterfaceNumber = INTERFACE_ID_CDC_DCI,
    },

    .CDC_NotificationEndpoint =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Endpoint_t),
            .Type = DTYPE_Endpoint},

        .EndpointAddress = CDC_NOTIFICATION_EPADDR,
        .EndpointSize = CDC_NOTIFICATION_EPSIZE,
        .Attributes = (EP_TYPE_INTERRUPT
                       | ENDPOINT_ATTR_NO_SYNC
                       | ENDPOINT_USAGE_DATA),

        .PollingIntervalMS = 0xFF
    },

    .CDC_DCI_Interface =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Interface_t),
            .Type = DTYPE_Interface},

        .InterfaceNumber = INTERFACE_ID_CDC_DCI,
        .AlternateSetting = 0,

        .TotalEndpoints = 2,

        .Class = CDC_CSCP_CDCDataClass,
        .SubClass = CDC_CSCP_NoDataSubclass,
        .Protocol = CDC_CSCP_NoDataProtocol,

        .InterfaceStrIndex = NO_DESCRIPTOR
    },

    .CDC_DataOutEndpoint =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Endpoint_t),
            .Type = DTYPE_Endpoint},

        .EndpointAddress = CDC_RX_EPADDR,
        .Attributes = (EP_TYPE_BULK
                       | ENDPOINT_ATTR_NO_SYNC
                       | ENDPOINT_USAGE_DATA),

        .EndpointSize = CDC_TXRX_EPSIZE,
        .PollingIntervalMS = 0x05
    },

    .CDC_DataInEndpoint =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Endpoint_t),
            .Type = DTYPE_Endpoint},

        .EndpointAddress = CDC_TX_EPADDR,
        .Attributes = (EP_TYPE_BULK
                       | ENDPOINT_ATTR_NO_SYNC
                       | ENDPOINT_USAGE_DATA),

        .EndpointSize = CDC_TXRX_EPSIZE,
        .PollingIntervalMS = 0x05
    },
#endif

    .HID_Interface =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Interface_t),
            .Type = DTYPE_Interface},

        .InterfaceNumber = INTERFACE_ID_Mouse,
        .AlternateSetting = 0x00,

        .TotalEndpoints = 1,

        .Class = HID_CSCP_HIDClass,
        .SubClass = HID_CSCP_BootSubclass,
        .Protocol = HID_CSCP_MouseBootProtocol,

        .InterfaceStrIndex = NO_DESCRIPTOR
    },

    .HID_MouseHID =
    {
        .Header = {
            .Size = sizeof(USB_HID_Descriptor_HID_t),
            .Type = HID_DTYPE_HID},

        .HIDSpec = VERSION_BCD(1,1,1),
        .CountryCode = 0x00,
        .TotalReportDescriptors = 1,
        .HIDReportType = HID_DTYPE_Report,
        .HIDReportLength = sizeof(MouseReport)
    },

    .HID_ReportINEndpoint =
    {
        .Header = {
            .Size = sizeof(USB_Descriptor_Endpoint_t),
            .Type = DTYPE_Endpoint},

        .EndpointAddress = MOUSE_EPADDR,
        .Attributes = (EP_TYPE_INTERRUPT
                       | ENDPOINT_ATTR_NO_SYNC
                       | ENDPOINT_USAGE_DATA),
        .EndpointSize = MOUSE_EPSIZE,
        .PollingIntervalMS = POLLING_INTERVAL
    }
};

const USB_Descriptor_String_t PROGMEM LanguageString =
    USB_STRING_DESCRIPTOR_ARRAY(LANGUAGE_ID_ENG);
const USB_Descriptor_String_t PROGMEM ManufacturerString =
    USB_STRING_DESCRIPTOR(MANUFACTURER);
const USB_Descriptor_String_t PROGMEM ProductString =
    USB_STRING_DESCRIPTOR(PRODUCT);

uint16_t CALLBACK_USB_GetDescriptor(const uint16_t wValue,
                                    const uint16_t wIndex,
                                    const void** const DescriptorAddress)
{
    const uint8_t DescriptorType = (wValue >> 8);
    const uint8_t DescriptorNumber = (wValue & 0xff);

    switch (DescriptorType) {
        case DTYPE_Device:
            *DescriptorAddress = &DeviceDescriptor;
            return sizeof(USB_Descriptor_Device_t);

        case DTYPE_Configuration:
            *DescriptorAddress = &ConfigurationDescriptor;
            return sizeof(USB_Descriptor_Configuration_t);

        case DTYPE_String:
            switch (DescriptorNumber)
                {
                case STRING_ID_Language:
                    *DescriptorAddress = &LanguageString;
                    return pgm_read_byte(&LanguageString.Header.Size);

                case STRING_ID_Manufacturer:
                    *DescriptorAddress = &ManufacturerString;
                    return pgm_read_byte(&ManufacturerString.Header.Size);

                case STRING_ID_Product:
                    *DescriptorAddress = &ProductString;
                    return pgm_read_byte(&ProductString.Header.Size);

                default:
                    *DescriptorAddress = NULL;
                    return NO_DESCRIPTOR;
                }

        case HID_DTYPE_HID:
            *DescriptorAddress = &ConfigurationDescriptor.HID_MouseHID;
            return sizeof(USB_HID_Descriptor_HID_t);

        case HID_DTYPE_Report:
            *DescriptorAddress = &MouseReport;
            return sizeof(MouseReport);

        default:
            *DescriptorAddress = NULL;
            return NO_DESCRIPTOR;
        }
}

#ifdef ENABLE_CDC
USB_ClassInfo_CDC_Device_t CDC_Interface = {
    .Config =
    {
        .ControlInterfaceNumber = INTERFACE_ID_CDC_CCI,
        .DataINEndpoint = {
            .Address = CDC_TX_EPADDR,
            .Size = CDC_TXRX_EPSIZE,
            .Banks = 1,
        },

        .DataOUTEndpoint = {
            .Address = CDC_RX_EPADDR,
            .Size = CDC_TXRX_EPSIZE,
            .Banks = 1,
        },

        .NotificationEndpoint = {
            .Address = CDC_NOTIFICATION_EPADDR,
            .Size = CDC_NOTIFICATION_EPSIZE,
            .Banks = 1,
        },
    },
};
#endif

USB_ClassInfo_HID_Device_t HID_Interface = {
    .Config =
    {
        .InterfaceNumber = INTERFACE_ID_Mouse,
        .ReportINEndpoint =
        {
            .Address = MOUSE_EPADDR,
            .Size = MOUSE_EPSIZE,
            .Banks = 1,
        },
        .PrevReportINBuffer = NULL,
        .PrevReportINBufferSize = sizeof(MouseReport_Data_t),
    },
};

void do_usb_tasks(void)
{
#ifdef ENABLE_CDC
    CDC_Device_USBTask(&CDC_Interface);
#endif

    HID_Device_USBTask(&HID_Interface);
    USB_USBTask();
}

void EVENT_USB_Device_Connect(void)
{
}

void EVENT_USB_Device_Disconnect(void)
{
}

void EVENT_USB_Device_ConfigurationChanged(void)
{
    assert(HID_Device_ConfigureEndpoints(&HID_Interface));

#ifdef ENABLE_CDC
    assert(CDC_Device_ConfigureEndpoints(&CDC_Interface));
#endif

    USB_Device_EnableSOFEvents();
}

void EVENT_USB_Device_ControlRequest(void)
{
#ifdef ENABLE_CDC
    CDC_Device_ProcessControlRequest(&CDC_Interface);
#endif

    HID_Device_ProcessControlRequest(&HID_Interface);
}

void EVENT_USB_Device_StartOfFrame(void)
{
    HID_Device_MillisecondElapsed(&HID_Interface);
}

bool CALLBACK_HID_Device_CreateHIDReport(
    USB_ClassInfo_HID_Device_t *const HIDInterfaceInfo,
    uint8_t *const ReportID,
    const uint8_t ReportType,
    void* ReportData,
    uint16_t *const ReportSize)
{
    if (ReportType == HID_REPORT_ITEM_Feature) {
        static bool set;

        if (set) {
            return false;
        }

        FeatureReport_Data_t *p = (FeatureReport_Data_t *)ReportData;
        *ReportSize = sizeof(FeatureReport_Data_t);
        p->multiplier = 1;
        set = true;

        return true;
    } else {
        bool get_axes(int16_t *p);
        static uint8_t old_buttons, new_buttons, debounce_count;
        const uint8_t buttons[] = {BUTTONS};

        MouseReport_Data_t *p = (MouseReport_Data_t *)ReportData;
        *ReportSize = sizeof(MouseReport_Data_t);

        /* Read the current axes state and create the report. */

        p->buttons = old_buttons;
        const bool q = get_axes(p->axes);

        /* Read the current button state. */

        uint8_t b = 0;
        for (uint8_t i = 0; i < sizeof(buttons); i++) {
            b |= (((PIND & (1 << buttons[i])) == 0) << i);
        }

        if (!debounce_count) {
            /* If the button state changed, start debouncing. */

            if (b != old_buttons) {
                new_buttons = b;
                debounce_count = 1;
            }
        } else {
            /* Is the new button state stable? */

            if (b == new_buttons) {
                debounce_count += 1;
            } else {
                debounce_count = 1;
            }

            if (debounce_count > DEBOUNCE_INTERVAL) {
                /* Update the button state. */

                p->buttons = old_buttons = new_buttons;
                debounce_count = 0;
                return true;
            }
        }

        return q;
    }
}

void CALLBACK_HID_Device_ProcessHIDReport(
    USB_ClassInfo_HID_Device_t *const HIDInterfaceInfo,
    const uint8_t ReportID,
    const uint8_t ReportType,
    const void* ReportData,
    const uint16_t ReportSize)
{
}

#ifdef ENABLE_CDC
static volatile bool host_ready = false;

void EVENT_CDC_Device_ControLineStateChanged(
    USB_ClassInfo_CDC_Device_t *const CDCInterfaceInfo)
{
    host_ready = (CDCInterfaceInfo->State.ControlLineStates.HostToDevice
                  & CDC_CONTROL_LINE_OUT_DTR);
}

static int put(char c, FILE *fp)
{
    if (CDC_Device_SendByte(&CDC_Interface, c) != ENDPOINT_READYWAIT_NoError) {
        return 1;
    }

    if (c == '\n') {
        if (CDC_Device_Flush(&CDC_Interface) != ENDPOINT_READYWAIT_NoError) {;
            return 1;
        }
    }

    return 0;
}
#endif

void initialize_usb(void)
{
    USB_Init();
    GlobalInterruptEnable();

#ifdef ENABLE_CDC
    fdevopen(put, NULL);
#endif
}

void wait_for_host(void)
{
#ifdef ENABLE_CDC
    while (!host_ready) {
        do_usb_tasks();
    }
#endif
}
