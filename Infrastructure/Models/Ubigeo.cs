using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Ubigeo
{
    public int DistrictId { get; set; }

    public string Code { get; set; } = null!;

    public virtual District District { get; set; } = null!;

    public virtual ICollection<Person> People { get; set; } = new List<Person>();

    public virtual ICollection<StudentHome> StudentHomes { get; set; } = new List<StudentHome>();
}
