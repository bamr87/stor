from stor_dx.utils import is_dx_path
from stor_dx.dx import DXPath
from stor_dx import utils


def class_for_path(prefix, path):
    if prefix+'://' != DXPath.drive:
        raise ValueError('Invalid prefix to initialize DXPaths: {}'.format(prefix))
    cls = utils.find_dx_class(path)
    return cls, path