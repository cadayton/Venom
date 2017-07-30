# Show-VePureHostVols

Displays the volume(s) masked to a specified host.

Command line help for this cmdlet is available by executing the following.

    Get-Help Show-VePureHostVols -full

***

**Example**

    Show-VePureHostVols -pureName bowpure002 -hostName testdummy02

    vol             name        lun hgroup
    ---             ----        --- ------
    testdummy02_T   testdummy02   1
    testdummy01_S_X testdummy02   2
    testdummy01_S_Y testdummy02   3
    testdummy01_S_Z testdummy02   4
    testdummy01_S_A testdummy02   5

    name            created              source        serial                   Size(GB)
    ----            -------              ------        ------                   --------
    testdummy02_T   2017-06-05T21:19:59Z               C7227C857D1B97E900011455       10
    testdummy01_S_X 2017-06-12T19:13:07Z testdummy01_S C7227C857D1B97E900011469       10
    testdummy01_S_Y 2017-07-28T18:33:30Z testdummy01_S C7227C857D1B97E900011473       10
    testdummy01_S_Z 2017-07-30T04:19:44Z testdummy01_S C7227C857D1B97E900011478       10
    testdummy01_S_A 2017-07-30T04:20:04Z testdummy01_S C7227C857D1B97E900011479       10

