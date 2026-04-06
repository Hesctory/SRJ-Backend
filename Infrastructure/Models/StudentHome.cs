using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class StudentHome
{
    public int StudentId { get; set; }

    public int? AddressUbigeoId { get; set; }

    public bool HasElectronicDevices { get; set; }

    public bool HasInternetAccess { get; set; }

    public virtual Ubigeo? AddressUbigeo { get; set; }

    public virtual Student Student { get; set; } = null!;
}
