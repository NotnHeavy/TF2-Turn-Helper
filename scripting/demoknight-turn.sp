// i don't understand game maths and i wrote this very quickly

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <tf2>
#include <tf2_stocks>

#define M_E        2.71828182845904523536   // e
#define M_LOG2E    1.44269504088896340736   // log2(e)
#define M_LOG10E   0.434294481903251827651  // log10(e)
#define M_LN2      0.693147180559945309417  // ln(2)
#define M_LN10     2.30258509299404568402   // ln(10)
#define M_PI       3.14159265358979323846   // pi
#define M_PI_2     1.57079632679489661923   // pi/2
#define M_PI_4     0.785398163397448309616  // pi/4
#define M_1_PI     0.318309886183790671538  // 1/pi
#define M_2_PI     0.636619772367581343076  // 2/pi
#define M_2_SQRTPI 1.12837916709551257390   // 2/sqrt(pi)
#define M_SQRT2    1.41421356237309504880   // sqrt(2)
#define M_SQRT1_2  0.707106781186547524401  // 1/sqrt(2)

Handle sync;
bool toggle[MAXPLAYERS + 1];
bool extra[MAXPLAYERS + 1];
bool speedometer[MAXPLAYERS + 1];

float lastspeed[MAXPLAYERS + 1];
float lastchangedspeed[MAXPLAYERS + 1];

public void OnPluginStart()
{
    sync = CreateHudSynchronizer();
    RegConsoleCmd("chargetoggle", chargetoggle);
    RegConsoleCmd("extratoggle", extratoggle);
    RegConsoleCmd("speedtoggle", speedtoggle);
}

Action chargetoggle(int client, int args)
{
    toggle[client] = !toggle[client];
    return Plugin_Continue;
}

Action extratoggle(int client, int args)
{
    extra[client] = !extra[client];
    return Plugin_Continue;
}

Action speedtoggle(int client, int args)
{
    speedometer[client] = !speedometer[client];
    return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
    toggle[client] = false;
}

int abs(int x)
{
    int mask = x >> 32 - 1;
    return (x + mask) ^ mask;
}

public void OnGameFrame()
{
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsValidEntity(i) && IsClientInGame(i))
        {
            if (toggle[i])
            {
                float m_angAbsRotation[3];
                float m_vecAbsVelocity[3];
                float angleVector[3];

                GetEntPropVector(i, Prop_Data, "m_angAbsRotation", m_angAbsRotation);
                GetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", m_vecAbsVelocity);
                NormalizeVector(m_vecAbsVelocity, m_vecAbsVelocity);
                m_vecAbsVelocity[2] = 0.00;
                GetVectorAngles(m_vecAbsVelocity, angleVector);
                if (m_angAbsRotation[1] < 0)
                    m_angAbsRotation[1]  += 360.00;
            
                // there's 
                float difference = m_angAbsRotation[1] - angleVector[1];
                if (difference <= -180.00)
                    difference += 360.00;
                else if (difference >= 180.00)
                    difference -= 360.00;

                int angle = RoundFloat(difference);

                GetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", m_vecAbsVelocity);
                m_vecAbsVelocity[2] = 0.00;
                float speed = GetVectorLength(m_vecAbsVelocity);

                // https://steamcommunity.com/sharedfiles/filedetails/?id=184184420
                int optimal = RoundFloat(ArcCosine((750.00 - FloatAbs(0.0152 * 7500.00)) / FloatAbs(speed)) * (180 / M_PI));
                int minimum = RoundFloat(ArcCosine(750.00 / FloatAbs(speed)) * (180 / M_PI));
                if (!TF2_IsPlayerInCondition(i, TFCond_Charging) || abs(angle) > optimal + 20 || abs(angle) < minimum - 10 || (speed - lastspeed[i] < 10.00 && GetGameTime() - lastchangedspeed[i] >= 0.1))
                    SetHudTextParams(-1.0, 0.4, 1.00, 255, 0, 0, 255, 0, 6.0, 0.0, 0.0);  // red
                else if (abs(angle) < optimal - 10 || abs(angle) > optimal + 10)
                    SetHudTextParams(-1.0, 0.4, 1.00, 127, 255, 0, 255, 0, 6.0, 0.0, 0.0); // yellow
                else if (abs(angle) < optimal - 5 || abs(angle) > optimal + 5)
                    SetHudTextParams(-1.0, 0.4, 1.00, 0, 255, 255, 255, 0, 6.0, 0.0, 0.0); // turquoise
                else
                    SetHudTextParams(-1.0, 0.4, 1.00, 0, 255, 0, 255, 0, 6.0, 0.0, 0.0); // green

                char extrabuffer[256];
                char speedbuffer[256];
                Format(extrabuffer, sizeof(extrabuffer), "\nmin: %i, max: %i", minimum, optimal);
                Format(speedbuffer, sizeof(speedbuffer), "\nspeed: %i", RoundFloat(speed));
                ShowSyncHudText(i, sync, "%i%s%s", speed == 0 ? 0 : angle, extra[i] ? extrabuffer : "", speedometer[i] ? speedbuffer : "");

                if (speed - lastspeed[i] > 0.5 || lastspeed[i] - speed > 0.5)
                {
                    lastspeed[i] = speed;
                    lastchangedspeed[i] = GetGameTime();
                }
            }
        }
    }
}