import copy
import mock
import os
from storage_utils import settings
import threading
import time
import unittest

test_settings = {
    'swift:download': {
        'container_threads': 10,
        'object_threads': 10,
        'shuffle': True,
        'skip_identical': True
    },
    'swift:upload': {
        'changed': False,
        'checksum': True,
        'leave_segments': True,
        'object_threads': 10,
        'segment_size': 1073741824,
        'segment_threads': 10,
        'skip_identical': False,
        'use_slo': True
    }
}


@mock.patch.dict('storage_utils.settings._global_settings', copy.deepcopy(test_settings),
                 clear=True)
class TestSettings(unittest.TestCase):
    def test_initialize_default(self):
        expected_settings = {
            'stor': {},
            's3': {},
            's3:upload': {
                'object_threads': 10
            },
            's3:download': {
                'object_threads': 10
            },
            'swift': {},
            'swift:delete': {
                'object_threads': 10
            },
            'swift:download': {
                'container_threads': 10,
                'object_threads': 10,
                'shuffle': True,
                'skip_identical': True
            },
            'swift:upload': {
                'changed': False,
                'checksum': True,
                'leave_segments': True,
                'object_threads': 10,
                'segment_size': 1073741824,
                'segment_threads': 10,
                'skip_identical': False,
                'use_slo': True
            }
        }
        settings._initialize()
        self.assertEquals(settings._global_settings, expected_settings)

    def test_initialize_file(self):
        expected_settings = {
            'stor': {
                'str_val': 'this is a string'
            },
            'something': {
                'just': 'another value'
            },
            'swift': {
                'num_retries': 5,
                'fake_secret_key': '7jsdf0983j""SP{}?//'
            },
            'swift:download': {
                'container_threads': 10,
                'object_threads': 10,
                'shuffle': True,
                'skip_identical': True
            },
            'swift:upload': {
                'changed': False,
                'checksum': True,
                'leave_segments': True,
                'object_threads': 10,
                'segment_size': 1073741824,
                'segment_threads': 10,
                'skip_identical': False,
                'use_slo': True
            }
        }
        filename = os.path.join(os.path.dirname(__file__), 'file_data', 'test.cfg')
        settings._initialize(filename)
        self.assertEquals(settings._global_settings, expected_settings)

    def test_get(self):
        self.assertEquals(settings.get(), test_settings)

    @mock.patch.dict('storage_utils.settings._global_settings',
                     copy.deepcopy(test_settings), clear=True)
    def test_update_w_settings(self):
        update_settings = {
            'swift:upload': {
                'skip_identical': True,
                'object_threads': 30
            },
            'swift:download': {
                'object_threads': 20
            }
        }
        expected_settings = {
            'swift:download': {
                'container_threads': 10,
                'object_threads': 20,
                'shuffle': True,
                'skip_identical': True
            },
            'swift:upload': {
                'changed': False,
                'checksum': True,
                'leave_segments': True,
                'object_threads': 30,
                'segment_size': 1073741824,
                'segment_threads': 10,
                'skip_identical': True,
                'use_slo': True
            }
        }
        settings.update(settings=update_settings)
        self.assertEquals(settings._global_settings, expected_settings)

    def test_update_wo_settings(self):
        settings.update()
        self.assertEquals(settings._global_settings, test_settings)

    def test_use_w_settings(self):
        update_settings = {
            'swift:upload': {
                'skip_identical': True,
                'object_threads': 30
            },
            'swift:download': {
                'object_threads': 20
            }
        }
        expected_settings = {
            'swift:download': {
                'container_threads': 10,
                'object_threads': 20,
                'shuffle': True,
                'skip_identical': True
            },
            'swift:upload': {
                'changed': False,
                'checksum': True,
                'leave_segments': True,
                'object_threads': 30,
                'segment_size': 1073741824,
                'segment_threads': 10,
                'skip_identical': True,
                'use_slo': True
            }
        }

        self.assertEquals(settings._global_settings, test_settings)
        with settings.use(update_settings):
            self.assertEquals(settings._global_settings, test_settings)
            self.assertEquals(settings.get(), expected_settings)
        self.assertEquals(settings._global_settings, test_settings)
        self.assertEquals(settings.get(), test_settings)

    def test_use_wo_settings(self):
        self.assertEquals(settings._global_settings, test_settings)
        with settings.use():
            self.assertEquals(settings._global_settings, test_settings)
        self.assertEquals(settings._global_settings, test_settings)

    @mock.patch.dict('storage_utils.settings._global_settings', clear=True)
    def test_use_nested_w_update(self):
        settings.update({'foo': 0})
        self.assertEquals(settings.get(), {'foo': 0})
        with settings.use({'foo': 1}):
            self.assertEquals(settings.get(), {'foo': 1})
            self.assertEquals(settings._global_settings, {'foo': 0})
            with settings.use({'foo': 2}):
                self.assertEquals(settings.get(), {'foo': 2})
                self.assertEquals(settings._global_settings, {'foo': 0})
            self.assertEquals(settings.get(), {'foo': 1})
            self.assertEquals(settings._global_settings, {'foo': 0})
        self.assertEquals(settings.get(), {'foo': 0})
        self.assertFalse(hasattr(settings.thread_local, 'settings'))
        settings.update({'foo': 3})
        self.assertEquals(settings.get(), {'foo': 3})

    @mock.patch.dict('storage_utils.settings._global_settings', clear=True)
    def test_use_update_w_error(self):
        with settings.use({'foo': 1}):
            with self.assertRaises(RuntimeError):
                settings.update({'foo': 3})

    def _use_contextmanager(self, value):
        with settings.use({'foo': value}):
            time.sleep(.01)
            self.assertEquals(settings.get(), {'foo': value})
            time.sleep(.01)

    @mock.patch.dict('storage_utils.settings._global_settings', clear=True)
    def test_use_multithreaded(self):
        threads = []
        for i in range(30):
            thread = threading.Thread(target=self._use_contextmanager, args=(i,))
            threads.append(thread)
            thread.start()

        for thread in threads:
            thread.join()
