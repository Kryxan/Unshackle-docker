import random
import re
import subprocess
from typing import Optional

from unshackle.core import binaries
from unshackle.core.proxies.proxy import Proxy


class Hola(Proxy):
    def __init__(self):
        """
        Proxy Service using Hola's direct connections via the hola-proxy project.
        https://github.com/Snawoot/hola-proxy
        """
        self.binary = binaries.HolaProxy
        if not self.binary:
            raise EnvironmentError("hola-proxy executable not found but is required for the Hola proxy provider.")
        
        # DNS resolvers to bypass DNS blocking (Cloudflare, Google, Quad9)
        self.dns_resolvers = "https://1.1.1.1/dns-query,https://8.8.8.8/dns-query,https://9.9.9.9/dns-query"
        self.countries = self.get_countries()

    def __repr__(self) -> str:
        countries = len(self.countries)

        return f"{countries} Countr{['ies', 'y'][countries == 1]}"

    def get_proxy(self, query: str) -> Optional[str]:
        """
        Get an HTTP proxy URI for a Datacenter ('direct') or Residential ('lum') Hola server.
        
        TODO: - Add ability to select 'lum' proxies (residential proxies).
              - Return and use Proxy Authorization
        """
        query = query.lower()

        p = subprocess.check_output(
            [self.binary, "-country", query, "-list-proxies", "-resolver", self.dns_resolvers, "-verbosity", "50"], 
            stderr=subprocess.STDOUT
        ).decode()

        if "Transaction error: temporary ban detected." in p:
            raise ConnectionError("Hola banned your IP temporarily from it's services. Try change your IP.")

        username, password, proxy_authorization = re.search(
            r"Login: (.*)\nPassword: (.*)\nProxy-Authorization: (.*)", p
        ).groups()

        servers = re.findall(r"(zagent.*)", p)
        proxies = []
        for server in servers:
            host, ip_address, direct, peer, hola, trial, trial_peer, vendor = server.split(",")
            proxies.append(f"http://{username}:{password}@{ip_address}:{peer}")

        proxy = random.choice(proxies)
        return proxy

    def get_countries(self) -> list[dict[str, str]]:
        """Get a list of available Countries."""
        p = subprocess.check_output(
            [self.binary, "-list-countries", "-resolver", self.dns_resolvers, "-verbosity", "50"]
        ).decode("utf8")
        
        return [{code: name} for country in p.splitlines() for (code, name) in [country.split(" - ", maxsplit=1)]]
