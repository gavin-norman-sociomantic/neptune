/*******************************************************************************

    Git-cmd interaction helper

    Copyright:
        Copyright (c) 2017 sociomantic labs GmbH. All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE.txt for details.

*******************************************************************************/

module internal.git.helper;

import internal.shell.helper;

/***************************************************************************

    Finds out if ref1 is an ancestor of ref2

    Params:
        ref1 = ref to check if it is an ancestor of ref2
        ref2 = ref to check if it is a decendant of ref1

    Returns:
        true if ref1 is an ancestor of ref2

***************************************************************************/

bool isAncestor ( string ref1, string ref2 )
{
    import std.process : executeShell;
    import std.format;

    auto c = executeShell(format("git merge-base --is-ancestor %s %s",
                                 ref1, ref2));

    // Status 0 => is ancestor
    // Status 1 => is not
    if (c.status != 0 && c.status != 1)
        throw new Exception(c.output);

    return c.status == 0;
}


/*******************************************************************************

    Params:
        file = file to get last commit for

    Returns:
        last commit for the given file

*******************************************************************************/

string getLastCommitOf ( string file )
{
    return cmd(`git log -n 1 --pretty="%H" ` ~ file);
}


/*******************************************************************************

    Returns:
        the currently checked out branch

*******************************************************************************/

string getCurrentBranch ( )
{
    import internal.shell.helper;
    import std.string;

    auto branch = cmd("git symbolic-ref --short HEAD");

    if (branch.startsWith("heads/"))
        return branch["heads/".length .. $];

    return branch;
}


/*******************************************************************************

    Params:
        app_name = name of the app who's configuration should be used
        upstream = upstream to use for getting the data

    Returns:
        The upstream remote name

*******************************************************************************/

string getRemote ( string app_name, string upstream )
{
    import std.algorithm.iteration : splitter, uniq, map, filter;
    import std.algorithm.searching: canFind;
    import std.range;
    import std.conv;
    import std.regex;
    import std.format;
    import std.exception;

    auto upstream_config = app_name ~ ".upstreamremote";

    try return getConfig(upstream_config);
    catch (Exception exc)
    {
        auto remotes = cmd("git remote -v")
            .splitter!(a=>a == '\n')
            .uniq()
            .filter!(a=>a.matchAll(r"github\.com[:/]" ~ upstream))
            .map!(a=>a.splitter!(a=>a == ' ' || a == '\t').front);

        auto guessed_remote = remotes.empty ? "" : remotes.front.array.to!string;
        auto asked_remote = readString(
                                       format("Please enter the upstream remote name.\nWill default to [%s]: ",
                                              guessed_remote), true, true);

        string remote;

        if (asked_remote.empty)
            remote = guessed_remote;
        else
            remote = asked_remote;

        if (remote.empty)
            throw new Exception(
                                format("Can't find your upstream remote for %s", upstream));

        cmd("git config " ~ upstream_config ~ " " ~ remote);

        return remote;
    }
}


/*******************************************************************************

    Extracts the annotated message of a tag

    Params:
        tag = tag to extract message from

    Returns:
        extracted message

*******************************************************************************/

string getTagMessage ( string tag )
{
    import std.format;
    import std.algorithm.searching : findSplitBefore;

    auto result = cmd(["git", "cat-file", tag, "-p"]).linesFrom(6);

    return result.findSplitBefore("\n-----BEGIN PGP SIGNATURE-----")[0];
}


/*******************************************************************************

    Params:
        app_name = name of the app configuration to use
    Returns:
        the configured <app_name>.upstream variable. If not found, asks the user to
        set it up.

*******************************************************************************/

string getUpstream ( string app_name )
{
    import std.exception;

    return cmd("git config "~app_name~".upstream")
              .ifThrown(configureUpstream(app_name, askUpstreamName()));
}


/*******************************************************************************

    Params:
        path = config path to get

    Returns:
        requested config path valu

*******************************************************************************/

string getConfig ( string path )
{
    import std.format;
    return cmd(format("git config %s", path));
}


/*******************************************************************************

    Configures neptune upstream

    Params:
        app_name = which app configuration to use
        upstream = desired upstream

    Returns:
        the new upstream

*******************************************************************************/

string configureUpstream ( string app_name, string upstream )
{
    cmd("git config " ~ app_name ~ ".upstream " ~ upstream);

    return upstream;
}
