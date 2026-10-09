"""One new, unfunded anonymous bot tests the real store refusal."""
import e2e_match as h
import new_roles_tools_match as suite


def main():
    bot = h._anon_session_new('UnfundedBot')
    response = suite.eco(bot, 'toolBuy', tool='appeal', pack=7, requestId=h.aid())
    suite.refused('fresh bot insufficient coins', response, ['INSUFFICIENT_COINS'])
