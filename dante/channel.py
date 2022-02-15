class DanteChannel():
    def __init__(self):
        self._channel_type = None
        self._device = None
        self._friendly_name = None
        self._name = None
        self._number = None
        self._status_codes = None
        self._status_text = None
        self._volume = None


    def __str__(self):
        name = self.name

        if self.friendly_name:
            name = self.friendly_name

        if self.volume and self.volume != 254:
            text = f'{self.number}:{name} [{self.volume}]'
        else:
            text = f'{self.number}:{self.name}'

        return text


    @property
    def device(self):
        return self._device


    @device.setter
    def device(self, device):
        self._device = device


    @property
    def number(self):
        return self._number


    @number.setter
    def number(self, number):
        self._number = number


    @property
    def status_codes(self):
        return self._status_codes


    @status_codes.setter
    def status_codes(self, status_codes):
        self._status_codes = status_codes


    @property
    def status_text(self):
        return self._status_text


    @status_text.setter
    def status_text(self, status_text):
        self._status_text = status_text


    @property
    def channel_type(self):
        return self._channel_type


    @channel_type.setter
    def channel_type(self, channel_type):
        self._channel_type = channel_type


    @property
    def friendly_name(self):
        return self._friendly_name


    @friendly_name.setter
    def friendly_name(self, friendly_name):
        self._friendly_name = friendly_name


    @property
    def name(self):
        return self._name


    @name.setter
    def name(self, name):
        self._name = name


    @property
    def volume(self):
        return self._volume


    @volume.setter
    def volume(self, volume):
        self._volume = volume


    def to_json(self):
        as_json = {
            'number': self.number,
            'name': self.name
        }

        if self.friendly_name:
            as_json['friendly_name'] = self.friendly_name

        if self.status_text:
            as_json['status_text'] = self.status_text

        if self.volume:
            as_json['volume'] = self.volume

        return {key:as_json[key] for key in sorted(as_json.keys())}
