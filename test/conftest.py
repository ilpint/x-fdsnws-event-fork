import pytest
from requests.auth import HTTPBasicAuth


def pytest_addoption(parser):
    parser.addoption("--host", action="store", default="localhost:8087", help="Database host")
    parser.addoption("--user", action="store", default="admin", help="user name")
    parser.addoption("--pass", action="store", default="admin", help="user password")


@pytest.fixture
def host(pytestconfig):
    return pytestconfig.getoption("host")


@pytest.fixture
def basicAuth(pytestconfig):
    return HTTPBasicAuth(
        pytestconfig.getoption("user"),
        pytestconfig.getoption("pass"),
    )


def pytest_addoption(parser):
    parser.addoption("--host", action="store", default="localhost:8087", help="Database host")
    parser.addoption("--user", action="store", default="admin", help="user name")
    parser.addoption("--pass", action="store", default="admin", help="user password")




