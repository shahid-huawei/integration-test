*** Settings ***
Documentation     Functional test for bgp - l3vpn-mutlicast
...
...               Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
...
...               This program and the accompanying materials are made available under the
...               terms of the Eclipse Public License v1.0 which accompanies this distbmution,
...               and is available at http://www.eclipse.org/legal/epl-v10.html
...
...               This suite tests advertising l3vpn_mcast routes to odl. For advertising play.py is used,
...               and particular files are stored as *.hex files.
...               There are L3vpn-ipv4-multicast routes and L3vpn-ipv6-multicast routes tested.
...               TODO: Unify Keywords with 060_bgp_functional_mvpn.robot test suite
Suite Setup       Start_Suite
Suite Teardown    Stop_Suite
Test Setup        SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
Library           RequestsLibrary
Library           SSHLibrary
Library           String
Library           ../../../libraries/BgpRpcClient.py    ${TOOLS_SYSTEM_IP}
Resource          ../../../libraries/BGPcliKeywords.robot
Resource          ../../../libraries/BGPSpeaker.robot
Resource          ../../../libraries/SetupUtils.robot
Resource          ../../../libraries/SSHKeywords.robot
Resource          ../../../libraries/TemplatedRequests.robot
Resource          ../../../variables/Variables.robot

*** Variables ***
${HOLDTIME}       180
${CONFIG_SESSION}    config-session
${L3VPN_MCAST_DIR}    ${CURDIR}/../../../variables/bgpfunctional/l3vpn_mcast
${PLAY_SCRIPT}    ${CURDIR}/../../../../tools/fastbgp/play.py
${RIB_NAME}       example-bgp-rib
&{L3VPN_MCAST_ADJ_RIB_IN}    PATH=peer/bgp:%2F%2F${TOOLS_SYSTEM_IP}/adj-rib-in    BGP_RIB=${RIB_NAME}
&{L3VPN_MCAST_LOC_RIB}    PATH=loc-rib    BGP_RIB=${RIB_NAME}
&{L3VPN_MCAST_EFFECTIVE_RIB_IN}    PATH=peer/bgp:%2F%2F${TOOLS_SYSTEM_IP}/effective-rib-in    BGP_RIB=${RIB_NAME}
&{L3VPN_MCAST_APP_PEER}    IP=${ODL_SYSTEM_IP}    BGP_RIB=${RIB_NAME}
&{L3VPN_MCAST_ODL_CONFIG}    IP=${TOOLS_SYSTEM_IP}    HOLDTIME=${HOLDTIME}    PEER_PORT=${BGP_TOOL_PORT}    INITIATE=false    BGP_RIB=${RIB_NAME}    PASSIVE_MODE=true

*** Test Cases ***
Configure_App_Peer
    [Documentation]    Configures bgp application peer.
    [Setup]    SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
    TemplatedRequests.Put_As_Xml_Templated    ${L3VPN_MCAST_DIR}/app_peer    mapping=${L3VPN_MCAST_APP_PEER}    session=${CONFIG_SESSION}

Reconfigure_ODL_To_Accept_Connection
    [Documentation]    Configures BGP peer module with initiate-connection set to false.
    [Setup]    SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
    TemplatedRequests.Put_As_Xml_Templated    ${L3VPN_MCAST_DIR}/bgp_peer    mapping=${L3VPN_MCAST_ODL_CONFIG}    session=${CONFIG_SESSION}

Start_Bgp_Peer
    [Documentation]    Start Python speaker to connect to ODL. We need to do WUKS until odl really starts to accept incomming bgp connection. The failure happens if the incomming connection comes too quickly after configuring the peer in the previous test case.
    [Setup]    SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
    BuiltIn.Wait_Until_Keyword_Succeeds    3x    1s    Start Bgp Peer

Odl_To_Play_l3vpn_mcast
    [Template]    Odl_To_Play_Template
    l3vpn_mcast

Play_To_Odl_l3vpn_mcast
    [Template]    Play_To_Odl_Template
    l3vpn_mcast

Odl_To_Play_l3vpn_mcast_ipv6
    [Template]    Odl_To_Play_Template
    l3vpn_mcast_ipv6

Play_To_Odl_l3vpn_mcast_ipv6
    [Template]    Play_To_Odl_Template
    l3vpn_mcast_ipv6

Kill_Talking_BGP_Speaker
    [Documentation]    Abort the Python speaker
    [Setup]    SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
    BGPSpeaker.Kill_BGP_Speaker
    BGPcliKeywords.Store_File_To_Workspace    play.py.out    l3vpn_mcast_play.log

Delete_Bgp_Peer_Configuration
    [Documentation]    Revert the BGP configuration to the original state: without any configured peers.
    [Setup]    SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
    TemplatedRequests.Delete_Templated    ${L3VPN_MCAST_DIR}/bgp_peer    mapping=${L3VPN_MCAST_ODL_CONFIG}    session=${CONFIG_SESSION}

Deconfigure_App_Peer
    [Documentation]    Revert the BGP configuration to the original state: without application peer
    [Setup]    SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing
    TemplatedRequests.Delete_Templated    ${L3VPN_MCAST_DIR}/app_peer    mapping=${L3VPN_MCAST_APP_PEER}    session=${CONFIG_SESSION}

*** Keywords ***
Start_Suite
    [Documentation]    Initialize SetupUtils. Suite setup keyword.
    SetupUtils.Setup_Utils_For_Setup_And_Teardown
    ${mininet_conn_id} =    SSHLibrary.Open Connection    ${TOOLS_SYSTEM_IP}    prompt=${DEFAULT_LINUX_PROMPT}    timeout=6s
    Builtin.Set Suite Variable    ${mininet_conn_id}
    SSHKeywords.Flexible Mininet Login    ${TOOLS_SYSTEM_USER}
    RequestsLibrary.Create Session    ${CONFIG_SESSION}    http://${ODL_SYSTEM_IP}:${RESTCONFPORT}    auth=${AUTH}
    SSHLibrary.Put File    ${PLAY_SCRIPT}    .
    SSHKeywords.Assure_Library_Ipaddr    target_dir=.

Stop_Suite
    [Documentation]    Suite teardown keyword
    SSHLibrary.Close_All_Connections
    RequestsLibrary.Delete_All_Sessions

Start_Bgp_Peer
    [Documentation]    Starts bgp peer and verifies that the peer runs.
    BGPSpeaker.Start_BGP_Speaker    --amount 0 --myip=${TOOLS_SYSTEM_IP} --myport=${BGP_TOOL_PORT} --peerip=${ODL_SYSTEM_IP} --peerport=${ODL_BGP_PORT} --debug --l3vpn_mcast --wfr 1
    BGPcliKeywords.Read_And_Fail_If_Prompt_Is_Seen

Odl_To_Play_Template
    [Arguments]    ${totest}
    ${announce_hex} =    OperatingSystem.Get_File    ${L3VPN_MCAST_DIR}/${totest}/announce_${totest}.hex
    ${announce_hex} =    String.Remove_String    ${announce_hex}    \n
    ${withdraw_hex} =    OperatingSystem.Get_File    ${L3VPN_MCAST_DIR}/${totest}/withdraw_${totest}.hex
    ${withdraw_hex} =    String.Remove_String    ${withdraw_hex}    \n
    BgpRpcClient.play_clean
    TemplatedRequests.Post_As_Xml_Templated    ${L3VPN_MCAST_DIR}/${totest}/app    mapping=${L3VPN_MCAST_APP_PEER}    session=${CONFIG_SESSION}
    ${update}    BuiltIn.Wait_Until_Keyword_Succeeds    3x    2s    Get_Update_Message
    BuiltIn.Should_Be_Equal_As_Strings    ${update}    ${announce_hex}
    BgpRpcClient.play_clean
    Remove_Configured_Routes    ${totest}
    ${update}    BuiltIn.Wait_Until_Keyword_Succeeds    3x    2s    Get_Update_Message
    BuiltIn.Should_Be_Equal_As_Strings    ${update}    ${withdraw_hex}
    [Teardown]    Remove_Configured_Routes    ${totest}

Play_To_Odl_Template
    [Arguments]    ${totest}
    ${announce_hex} =    OperatingSystem.Get_File    ${L3VPN_MCAST_DIR}/${totest}/announce_${totest}.hex
    ${withdraw_hex} =    OperatingSystem.Get_File    ${L3VPN_MCAST_DIR}/${totest}/withdraw_${totest}.hex
    BgpRpcClient.play_clean
    BgpRpcClient.play_send    ${announce_hex}
    BuiltIn.Wait_Until_Keyword_Succeeds    3x    2s    TemplatedRequests.Get_As_Json_Templated    ${L3VPN_MCAST_DIR}/${totest}/rib    mapping=${L3VPN_MCAST_ADJ_RIB_IN}    session=${CONFIG_SESSION}
    ...    verify=True
    BuiltIn.Wait_Until_Keyword_Succeeds    3x    2s    TemplatedRequests.Get_As_Json_Templated    ${L3VPN_MCAST_DIR}/${totest}/rib    mapping=${L3VPN_MCAST_EFFECTIVE_RIB_IN}    session=${CONFIG_SESSION}
    ...    verify=True
    BuiltIn.Wait_Until_Keyword_Succeeds    3x    2s    TemplatedRequests.Get_As_Json_Templated    ${L3VPN_MCAST_DIR}/${totest}/rib    mapping=${L3VPN_MCAST_LOC_RIB}    session=${CONFIG_SESSION}
    ...    verify=True
    BgpRpcClient.play_send    ${withdraw_hex}
    ${ipv} =    BuiltIn.Set_Variable_If    '${totest}' == 'l3vpn_mcast_ipv6'    l3vpn_mcast_ipv6    l3vpn_mcast
    BuiltIn.Wait_Until_Keyword_Succeeds    3x    2s    TemplatedRequests.Get_As_Json_Templated    ${L3VPN_MCAST_DIR}/empty_routes/${ipv}    mapping=${L3VPN_MCAST_LOC_RIB}    session=${CONFIG_SESSION}
    ...    verify=True
    [Teardown]    BgpRpcClient.play_send    ${withdraw_hex}

Get_Update_Message
    [Documentation]    Returns hex update message.
    ${update} =    BgpRpcClient.play_get
    BuiltIn.Should_Not_Be_Equal    ${update}    ${Empty}
    [Return]    ${update}

Remove_Configured_Routes
    [Arguments]    ${totest}
    [Documentation]    Removes the route if present.
    BuiltIn.Run_Keyword_And_Ignore_Error    TemplatedRequests.Delete_Templated    ${L3VPN_MCAST_DIR}/${totest}/app    mapping=${L3VPN_MCAST_APP_PEER}    session=${CONFIG_SESSION}
