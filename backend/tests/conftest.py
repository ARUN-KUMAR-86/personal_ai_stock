"""Pytest configuration and global test fixtures."""

import pytest
from app.database.session import init_db


@pytest.fixture(autouse=True, scope="session")
def setup_test_database():
    """Initializes tables in database before running tests."""
    init_db()
