using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Department
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public string Code { get; set; } = null!;

    public virtual ICollection<Province> Provinces { get; set; } = new List<Province>();
}
