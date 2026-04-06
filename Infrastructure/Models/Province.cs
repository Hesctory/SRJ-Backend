using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Province
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public int DepartmentId { get; set; }

    public string Code { get; set; } = null!;

    public virtual Department Department { get; set; } = null!;

    public virtual ICollection<District> Districts { get; set; } = new List<District>();
}
