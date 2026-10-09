"""Complete no-action timeout cycle with five existing cached accounts."""
import e2e_match as h
import new_roles_tools_match as n


def main():
    h._POOL_TAKEN[0] = 1
    n.BOTS = [h.anon_session('CachedBot%d' % i) for i in range(5)]
    n.timer_match()
