using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class WorkArea
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public virtual ICollection<EmploymentContract> EmploymentContracts { get; set; } = new List<EmploymentContract>();
}
