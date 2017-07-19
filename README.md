# Venom
[![Build status](https://ci.appveyor.com/api/projects/status/dktthvk43gwicc7l?svg=true)](https://ci.appveyor.com/project/cadayton/Venom)
[![Documentation Status](https://readthedocs.org/projects/venom/badge/?version=latest)](http://venom.readthedocs.io/en/latest/?badge=latest)

SAN Automation with PowerShell
***

Two fictitious Data Centers called the Snake and the Samish has a storage environment consisting of 97 storage arrays.  The SAN infrastructure consists of 78 director class fiber channel switches with over 24,000 host intiators and over 1,900 storage target ports. The SOS and Mojo organizations are the two primary tenants of the data centers. At any given time, there are about a million IOs in flight among the two data centers.

The **Venom** module is a collection of PowerShell cmdlets that ease the burden of maintaining a storage infrastructure of this scale.  This module is designed for the storage engineer who is in the trenches and desires quick access to SAN information.
