/*
 * InspIRCd -- Internet Relay Chat Daemon
 *
 *   Copyright (C) 2014 Justin Crawford <Justasic@Gmail.com>
 *   Copyright (C) 2013-2014, 2017-2022 Sadie Powell <sadie@witchery.services>
 *   Copyright (C) 2013-2014, 2016 Attila Molnar <attilamolnar@hush.com>
 *   Copyright (C) 2012, 2019 Robby <robby@chatbelgie.be>
 *   Copyright (C) 2012, 2014 Adam <Adam@anope.org>
 *   Copyright (C) 2010 Craig Edwards <brain@inspircd.org>
 *   Copyright (C) 2009-2010 Daniel De Graaf <danieldg@inspircd.org>
 *   Copyright (C) 2009 Uli Schlachter <psychon@inspircd.org>
 *   Copyright (C) 2008-2009 Robin Burchell <robin+git@viroteck.net>
 *
 * This file is part of InspIRCd.  InspIRCd is free software: you can
 * redistribute it and/or modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation, version 2.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#include "inspircd.h"
#include "listmode.h"
#include "timeutils.h"

#include <fstream>

/** Handles the +P channel mode
 */
class PermChannel final
	: public SimpleChannelMode
{
public:
	PermChannel(Module* Creator)
		: SimpleChannelMode(Creator, "permanent", 'P', true)
	{
	}

	bool OnModeChange(User* source, User* dest, Channel* channel, Modes::Change& change) override
	{
		if (SimpleChannelMode::OnModeChange(source, dest, channel, change))
		{
			if (!change.adding)
				channel->CheckDestroy();

			return true;
		}

		return false;
	}

	void SetOperOnly(bool value)
	{
		oper = value;
	}
};

// Not in a class due to circular dependency hell.
static std::string permchannelsconf;
static bool WriteDatabase(PermChannel& permchanmode, bool save_listmodes, unsigned char writeversion)
{
	/*
	 * We need to perform an atomic write so as not to fuck things up.
	 * So, let's write to a temporary file, flush it, then rename the file..
	 *     -- w00t
	 */

	// If the user has not specified a configuration file then we don't write one.
	if (permchannelsconf.empty())
		return true;

	const std::string permchannelsnewconf = permchannelsconf + ".new." + ConvToStr(ServerInstance->Time());
	std::ofstream stream(permchannelsnewconf);
	if (!stream.is_open())
	{
		ServerInstance->Logs.Critical(MODNAME, "Cannot create database \"{}\"! {} ({})", permchannelsnewconf, strerror(errno), errno);
		ServerInstance->SNO.WriteToSnoMask('a', "database: cannot create new permchan db \"{}\": {} ({})", permchannelsnewconf, strerror(errno), errno);
		return false;
	}

	stream
		<< "# This file was automatically generated by the " << INSPIRCD_VERSION << " permchannels module on " << Time::ToString(ServerInstance->Time()) << "." << std::endl
		<< "# Any changes to this file will be automatically overwritten." << std::endl
		<< std::endl;

	for (const auto& [_, chan] : ServerInstance->Channels.GetChans())
	{
		if (!chan->IsModeSet(permchanmode))
			continue;

		std::string chanmodes = chan->ChanModes(true);
		if (save_listmodes && writeversion == 1)
		{
			std::string modes;
			std::string params;

			for (auto* lm : ServerInstance->Modes.GetListModes())
			{
				ListModeBase::ModeList* list = lm->GetList(chan);
				if (!list || list->empty())
					continue;

				// Append the parameters
				for (const auto& entry : *list)
				{
					params += entry.mask;
					params += ' ';
				}

				// Append the mode letters (for example "IIII", "gg")
				modes.append(list->size(), lm->GetModeChar());
			}

			if (!params.empty())
			{
				// Remove the last space
				params.pop_back();

				// If there is at least a space in chanmodes (that is, a non-listmode has a parameter)
				// insert the listmode mode letters before the space. Otherwise just append them.
				std::string::size_type p = chanmodes.find(' ');
				if (p == std::string::npos)
					chanmodes += modes;
				else
					chanmodes.insert(p, modes);

				// Append the listmode parameters (the masks themselves)
				chanmodes += ' ';
				chanmodes += params;
			}
		}

		stream << "<permchannels channel=\"" << ServerConfig::Escape(chan->name)
			<< "\" ts=\"" << chan->age;

		if (!chan->topic.empty())
		{
			// Only store the topic if one is set.
			stream << "\" topic=\"" << ServerConfig::Escape(chan->topic)
				<< "\" topicts=\"" << chan->topicset
				<< "\" topicsetby=\"" << ServerConfig::Escape(chan->setby);
		}

		if (save_listmodes && writeversion >= 2)
		{
			for (auto* lm : ServerInstance->Modes.GetListModes())
			{
				ListModeBase::ModeList* list = lm->GetList(chan);
				if (!list || list->empty())
					continue;

				stream << "\" " << lm->name << "list=\"";
				for (auto entry = list->begin(); entry != list->end(); ++entry)
				{
					if (entry != list->begin())
						stream << ' ';
					stream << entry->mask << ' ' << entry->setter << ' ' << entry->time;
				}
			}
		}

		stream << "\" modes=\"" << ServerConfig::Escape(chanmodes)
			<< "\">" << std::endl;
	}

	if (stream.fail())
	{
		ServerInstance->Logs.Critical(MODNAME, "Cannot write to new database \"{}\"! {} ({})", permchannelsnewconf, strerror(errno), errno);
		ServerInstance->SNO.WriteToSnoMask('a', "database: cannot write to new permchan db \"{}\": {} ({})", permchannelsnewconf, strerror(errno), errno);
		return false;
	}
	stream.close();

#ifdef _WIN32
	remove(permchannelsconf.c_str());
#endif
	// Use rename to move temporary to new db - this is guaranteed not to fuck up, even in case of a crash.
	if (rename(permchannelsnewconf.c_str(), permchannelsconf.c_str()) < 0)
	{
		ServerInstance->Logs.Critical(MODNAME, "Cannot replace old database \"{}\" with new database \"{}\"! {} ({})", permchannelsconf, permchannelsnewconf, strerror(errno), errno);
		ServerInstance->SNO.WriteToSnoMask('a', "database: cannot replace old permchan db \"{}\" with new db \"{}\": {} ({})", permchannelsconf, permchannelsnewconf, strerror(errno), errno);
		return false;
	}

	return true;
}

class ModulePermanentChannels final
	: public Module
	, public Timer

{
private:
	PermChannel p;
	bool dirty = false;
	bool loaded = false;
	bool save_listmodes;
	unsigned long saveperiod;
	unsigned long maxbackoff;
	unsigned char backoff;
	unsigned char writeversion;

public:

	ModulePermanentChannels()
		: Module(VF_VENDOR, "Adds channel mode P (permanent) which prevents the channel from being deleted when the last user leaves.")
		, Timer(0, true)
		, p(this)
	{
	}

	void ReadConfig(ConfigStatus& status) override
	{
		const auto& tag = ServerInstance->Config->ConfValue("permchanneldb");
		permchannelsconf = tag->getString("filename");
		save_listmodes = tag->getBool("listmodes", true);
		p.SetOperOnly(tag->getBool("operonly", true));
		saveperiod = tag->getDuration("saveperiod", 5);
		backoff = tag->getNum<uint8_t>("backoff", 0);
		maxbackoff = tag->getDuration("maxbackoff", saveperiod * 120, saveperiod);
		writeversion = tag->getNum<unsigned char>("writeversion", 2, 1, 2);
		SetInterval(saveperiod);

		if (!permchannelsconf.empty())
			permchannelsconf = ServerInstance->Config->Paths.PrependConfig(permchannelsconf);
	}

	void LoadDatabase()
	{
		/*
		 * Process config-defined list of permanent channels.
		 * -- w00t
		 */
		for (const auto& [_, tag] : ServerInstance->Config->ConfTags("permchannels"))
		{
			std::string channel = tag->getString("channel");

			if (!ServerInstance->Channels.IsChannel(channel))
			{
				ServerInstance->Logs.Warning(MODNAME, "Ignoring permchannels tag with invalid channel name (\"" + channel + "\")");
				continue;
			}

			auto* c = ServerInstance->Channels.Find(channel);
			if (!c)
			{
				time_t TS = tag->getNum<time_t>("ts", ServerInstance->Time(), 1);
				c = new Channel(channel, TS);

				time_t topicset = tag->getNum<time_t>("topicts", 0);
				std::string topic = tag->getString("topic");

				if ((topicset != 0) || (!topic.empty()))
				{
					if (topicset == 0)
						topicset = ServerInstance->Time();
					std::string topicsetby = tag->getString("topicsetby");
					if (topicsetby.empty())
						topicsetby = ServerInstance->Config->GetServerName();
					c->SetTopic(ServerInstance->FakeClient, topic, topicset, &topicsetby);
				}

				ServerInstance->Logs.Debug(MODNAME, "Added {} with topic {}", channel, c->topic);

				irc::spacesepstream modes(tag->getString("modes"));
				std::string modechars;
				modes.GetToken(modechars);
				for (const auto modechr : modechars)
				{
					auto* mode = ServerInstance->Modes.FindMode(modechr, MODETYPE_CHANNEL);
					if (mode)
					{
						std::string param;
						if (mode->NeedsParam(true))
							modes.GetToken(param);

						Modes::Change modechange(mode, true, param);
						mode->OnModeChange(ServerInstance->FakeClient, ServerInstance->FakeClient, c, modechange);
					}
				}

				for (auto* lm : ServerInstance->Modes.GetListModes())
				{
					irc::spacesepstream listmodes(tag->getString(lm->name + "list"));

					std::string mask;
					std::string set_by;
					time_t set_at;
					while (listmodes.GetToken(mask) && listmodes.GetToken(set_by) && listmodes.GetNumericToken(set_at))
					{
						Modes::Change modechange(lm, true, mask, set_by, set_at);
						lm->OnModeChange(ServerInstance->FakeClient, ServerInstance->FakeClient, c, modechange);
					}
				}

				// We always apply the permchannels mode to permanent channels.
				Modes::Change modechange(&p, true);
				p.OnModeChange(ServerInstance->FakeClient, ServerInstance->FakeClient, c, modechange);
			}
		}
	}

	ModResult OnRawMode(User* user, Channel* chan, const Modes::Change& change) override
	{
		if (chan && (chan->IsModeSet(p) || change.mh == &p))
			dirty = true;

		return MOD_RES_PASSTHRU;
	}

	void OnPostTopicChange(User*, Channel* c, const std::string&) override
	{
		if (c->IsModeSet(p))
			dirty = true;
	}

	bool Tick() override
	{
		if (dirty)
		{
			if (WriteDatabase(p, save_listmodes, writeversion))
			{
				// If we were previously unable to write but now can then reset the time interval.
				if (GetInterval() != saveperiod)
					SetInterval(saveperiod, false);

				dirty = false;
			}
			else
			{
				// Back off a bit to avoid spamming opers.
				if (backoff > 1)
					SetInterval(std::min(GetInterval() * backoff, maxbackoff), false);
				ServerInstance->Logs.Debug(MODNAME, "Trying again in {} seconds", GetInterval());
			}
		}
		return true;
	}

	void Prioritize() override
	{
		// XXX: Load the DB here because the order in which modules are init()ed at boot is
		// alphabetical, this means we must wait until all modules have done their init()
		// to be able to set the modes they provide (e.g.: m_stripcolor is inited after us)
		// Prioritize() is called after all module initialization is complete, consequently
		// all modes are available now
		if (loaded)
			return;

		loaded = true;

		// Load only when there are no linked servers - we set the TS of the channels we
		// create to the current time, this can lead to desync because spanningtree has
		// no way of knowing what we do
		ProtocolInterface::ServerList serverlist;
		ServerInstance->PI->GetServerList(serverlist);
		if (serverlist.size() < 2)
		{
			try
			{
				LoadDatabase();
			}
			catch (const CoreException& e)
			{
				ServerInstance->Logs.Critical(MODNAME, "Error loading permchannels database: {}", e.what());
			}
		}
	}

	ModResult OnChannelPreDelete(Channel* c) override
	{
		if (c->IsModeSet(p))
			return MOD_RES_DENY;

		return MOD_RES_PASSTHRU;
	}
};

MODULE_INIT(ModulePermanentChannels)
