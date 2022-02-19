SERVICE_ARC: str = "_netaudio-arc._udp.local."
SERVICE_CHAN: str = "_netaudio-chan._udp.local."
SERVICE_CMC: str = "_netaudio-cmc._udp.local."
SERVICE_DBC: str = "_netaudio-dbc._udp.local."

SERVICES = [SERVICE_ARC, SERVICE_CHAN, SERVICE_CMC, SERVICE_DBC]

FEATURE_VOLUME_UNSUPPORTED = [
    "DAI1",
    "DAI2",
    "DAO1",
    "DAO2",
    "DIAES3",
    "DIOUSB",
    "DIUSBC",
    "_86012780000a0003",
]

STATUS_CONNECTED: str = "Connected"
STATUS_CONNECTED_UNICAST: str = "Connected (Unicast)"
STATUS_INCORRECT_CHANNEL_FORMAT: str = "Incorrect channel format"
STATUS_SELF_SUBSCRIBED: str = "Subscribed to own signal"
STATUS_UNRESOLVED: str = "Subscription unresolved"

REQUEST_DANTE_MODEL = 97
REQUEST_MAKE_MODEL = 193
RESPONSE_DANTE_MODEL = 96
RESPONSE_MAKE_MODEL = 192
TYPE_CHANNEL_COUNTS = 4096
TYPE_IDENTIFY_DEVICE = 4302

DEVICE_CONTROL_PORT: int = 8800
DEVICE_INFO_PORT: int = 8702
DEVICE_SETTINGS_PORT: int = 8700

PORTS = [DEVICE_CONTROL_PORT, DEVICE_INFO_PORT, DEVICE_SETTINGS_PORT]
