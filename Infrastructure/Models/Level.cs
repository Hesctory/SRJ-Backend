using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Level
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public int OrderIndex { get; set; }

    public virtual ICollection<Grade> Grades { get; set; } = new List<Grade>();

    public virtual ICollection<SchoolFee> SchoolFees { get; set; } = new List<SchoolFee>();
}
